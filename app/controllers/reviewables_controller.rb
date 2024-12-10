# frozen_string_literal: true

class ReviewablesController < ApplicationController
  requires_login

  PER_PAGE = 10

  before_action :version_required, only: %i[update perform]
  before_action :ensure_can_see, except: [:destroy]

  def index
    offset = params[:offset].to_i

    if params[:type].present?
      raise Discourse::InvalidParameters.new(:type) unless Reviewable.valid_type?(params[:type])
    end

    status = (params[:status] || "pending").to_sym
    raise Discourse::InvalidParameters.new(:status) if allowed_statuses.exclude?(status)

    topic_id = params[:topic_id] ? params[:topic_id].to_i : nil
    category_id = params[:category_id] ? params[:category_id].to_i : nil

    custom_keys = Reviewable.custom_filters.map(&:first)
    additional_filters =
      JSON.parse(params.fetch(:additional_filters, {}), symbolize_names: true).slice(*custom_keys)
    filters = {
      ids: params[:ids],
      status: status,
      category_id: category_id,
      topic_id: topic_id,
      additional_filters: additional_filters.reject { |_, v| v.blank? },
    }

    %i[
      priority
      username
      reviewed_by
      from_date
      to_date
      type
      sort_order
      flagged_by
    ].each { |filter_key| filters[filter_key] = params[filter_key] }

    total_rows = Reviewable.list_for(current_user, **filters).count
    reviewables =
      Reviewable.list_for(current_user, **filters.merge(limit: PER_PAGE, offset: offset)).to_a

    claimed_topics = ReviewableClaimedTopic.claimed_hash(reviewables.map { |r| r.topic_id }.uniq)

    # This is a bit awkward, but ActiveModel serializers doesn't seem to serialize STI. Note `hash`
    # is mutated by the serializer and contains the side loaded records which must be merged in the end.
    hash = {}
    json = {
      reviewables:
        reviewables.map! do |r|
          result =
            r
              .serializer
              .new(r, root: nil, hash: hash, scope: guardian, claimed_topics: claimed_topics)
              .as_json
          hash[:bundled_actions].uniq!
          (hash["actions"] || []).uniq!
          result
        end,
      meta:
        filters.merge(
          total_rows_reviewables: total_rows,
          types: meta_types,
          reviewable_types: Reviewable.types,
          reviewable_count: current_user.reviewable_count,
          unseen_reviewable_count: Reviewable.unseen_reviewable_count(current_user),
        ),
    }
    if (offset + PER_PAGE) < total_rows
      json[:meta][:load_more_reviewables] = review_path(filters.merge(offset: offset + PER_PAGE))
    end
    json.merge!(hash)

    render_json_dump(json, rest_serializer: true)
  end

  def user_menu_list
    json = {
      reviewables:
        Reviewable.basic_serializers_for_list(
          Reviewable.user_menu_list_for(current_user),
          current_user,
        ).as_json,
      reviewable_count: current_user.reviewable_count,
    }
    render_json_dump(json, rest_serializer: true)
  end

  def count
    render_json_dump(count: Reviewable.pending_count(current_user))
  end

  def topics
    topic_ids = Set.new

    stats = {}
    unique_users = {}

    # topics isn't indexed on `reviewable_score` and doesn't know what the current user can see,
    # so let's query from the inside out.
    pending = Reviewable.viewable_by(current_user).pending
    pending = pending.where("score >= ?", Reviewable.min_score_for_priority)

    pending.each do |r|
      topic_ids << r.topic_id

      meta = stats[r.topic_id] ||= { count: 0, unique_users: 0 }
      users = unique_users[r.topic_id] ||= Set.new

      r.reviewable_scores.each do |rs|
        users << rs.user_id
        meta[:count] += 1
      end
      meta[:unique_users] = users.size
    end

    topics = Topic.where(id: topic_ids).order("reviewable_score DESC")
    render_serialized(
      topics,
      ReviewableTopicSerializer,
      root: "reviewable_topics",
      stats: stats,
      claimed_topics: ReviewableClaimedTopic.claimed_hash(topic_ids),
      rest_serializer: true,
      meta: {
        types: meta_types,
      },
    )
  end

  def explain
    reviewable = find_reviewable

    render_serialized(
      { reviewable: reviewable, scores: reviewable.explain_score },
      ReviewableExplanationSerializer,
      rest_serializer: true,
      root: "reviewable_explanation",
    )
  end

  def show
    reviewable = find_reviewable

    render_serialized(
      reviewable,
      reviewable.serializer,
      rest_serializer: true,
      claimed_topics: ReviewableClaimedTopic.claimed_hash([reviewable.topic_id]),
      root: "reviewable",
      meta: {
        types: meta_types,
      },
    )
  end

  def destroy
    user =
      if is_api?
        if @guardian.is_admin?
          fetch_user_from_params
        else
          raise Discourse::InvalidAccess
        end
      else
        current_user
      end

    reviewable =
      Reviewable.find_by_flagger_or_queued_post_creator(
        id: params[:reviewable_id],
        user_id: user.id,
      )
    raise Discourse::NotFound.new if reviewable.blank?

    reviewable.perform(current_user, :delete, { guardian: @guardian })

    render json: success_json
  end

  def update
    reviewable = find_reviewable
    if error = claim_error?(reviewable)
      return render_json_error(error)
    end

    editable = reviewable.editable_for(guardian)
    raise Discourse::InvalidAccess.new if editable.blank?

    # Validate parameters are all editable
    edit_params = params[:reviewable] || {}
    edit_params.each do |name, value|
      if value.is_a?(ActionController::Parameters)
        value.each do |pay_name, pay_value|
          raise Discourse::InvalidAccess.new unless editable.has?("#{name}.#{pay_name}")
        end
      else
        raise Discourse::InvalidAccess.new unless editable.has?(name)
      end
    end

    begin
      if reviewable.update_fields(edit_params, current_user, version: params[:version].to_i)
        result = edit_params.merge(version: reviewable.version)
        render json: result
      else
        render_json_error(reviewable.errors)
      end
    rescue Reviewable::UpdateConflict
      render_json_error(I18n.t("reviewables.conflict"), status: 409)
    end
  end

  def perform
    args = { version: params[:version].to_i }

    result = nil
    begin
      reviewable = find_reviewable

      if error = claim_error?(reviewable)
        return render_json_error(error)
      end

      if reviewable.type_class.respond_to?(:additional_args)
        args.merge!(reviewable.type_class.additional_args(params) || {})
      end

      plugin_params =
        DiscoursePluginRegistry.reviewable_params.select do |reviewable_param|
          reviewable.type == reviewable_param[:type].to_s.classify
        end
      args.merge!(params.slice(*plugin_params.map { |pp| pp[:param] }).permit!)

      result = reviewable.perform(current_user, params[:action_id].to_sym, args)
    rescue Reviewable::InvalidAction => e
      if reviewable.type == "ReviewableUser" && !reviewable.pending? && reviewable.target.blank?
        raise Discourse::NotFound.new(
                e.message,
                custom_message: "reviewables.already_handled_and_user_not_exist",
              )
      else
        # Consider InvalidAction an InvalidAccess
        raise Discourse::InvalidAccess.new(e.message)
      end
    rescue Reviewable::UpdateConflict
      return render_json_error(I18n.t("reviewables.conflict"), status: 409)
    end

    if result.success?
      render_serialized(result, ReviewablePerformResultSerializer)
    else
      render_json_error(result)
    end
  end

  def settings
    raise Discourse::InvalidAccess.new unless current_user.admin?

    post_action_types = PostActionType.where(id: PostActionType.flag_types.values).order("id")

    if request.put?
      params[:reviewable_priorities].each do |id, priority|
        if !priority.nil? && Reviewable.priorities.has_value?(priority.to_i)
          # For now, the score bonus is equal to the priority. In the future we might want
          # to calculate it a different way.
          PostActionType.where(id: id).update_all(
            reviewable_priority: priority.to_i,
            score_bonus: priority.to_f,
          )
        end
      end
    end

    data = { reviewable_score_types: post_action_types }
    render_serialized(data, ReviewableSettingsSerializer, rest_serializer: true)
  end

  protected

  def claim_error?(reviewable)
    return if SiteSetting.reviewable_claiming == "disabled" || reviewable.topic_id.blank?

    claimed_by_id = ReviewableClaimedTopic.where(topic_id: reviewable.topic_id).pluck(:user_id)[0]

    if SiteSetting.reviewable_claiming == "required" && claimed_by_id.blank?
      I18n.t("reviewables.must_claim")
    elsif claimed_by_id.present? && claimed_by_id != current_user.id
      I18n.t("reviewables.user_claimed")
    end
  end

  def find_reviewable
    reviewable = Reviewable.viewable_by(current_user).where(id: params[:reviewable_id]).first
    raise Discourse::NotFound.new if reviewable.blank?
    reviewable
  end

  def allowed_statuses
    @allowed_statuses ||= (%i[reviewed all] + Reviewable.statuses.symbolize_keys.keys)
  end

  def version_required
    render_json_error(I18n.t("reviewables.missing_version"), status: 422) if params[:version].blank?
  end

  def meta_types
    { created_by: "user", target_created_by: "user", reviewed_by: "user", claimed_by: "user" }
  end

  def ensure_can_see
    Guardian.new(current_user).ensure_can_see_review_queue!
  end
end
