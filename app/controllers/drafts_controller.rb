# frozen_string_literal: true

class DraftsController < ApplicationController
  requires_login

  skip_before_action :check_xhr, :preload_json

  INDEX_LIMIT = 50

  def index
    params.permit(:offset)

    stream =
      Draft.stream(
        user: current_user,
        offset: params[:offset],
        limit: fetch_limit_from_params(default: nil, max: INDEX_LIMIT),
      )

    response = { drafts: serialize_data(stream, DraftSerializer) }

    if guardian.can_lazy_load_categories?
      category_ids = stream.map { |draft| draft.topic&.category_id }.compact.uniq
      categories = Category.secured(guardian).with_parents(category_ids)
      response[:categories] = serialize_data(categories, CategoryBadgeSerializer)
    end

    render json: response
  end

  def show
    raise Discourse::NotFound.new if params[:id].blank?

    seq = params[:sequence] || DraftSequence.current(current_user, params[:id])
    render json: { draft: Draft.get(current_user, params[:id], seq), draft_sequence: seq }
  end

  def create
    raise Discourse::NotFound.new if params[:draft_key].blank?

    if params[:data].size > SiteSetting.max_draft_length
      raise Discourse::InvalidParameters.new(:data)
    end

    begin
      data = JSON.parse(params[:data])
    rescue JSON::ParserError
      raise Discourse::InvalidParameters.new(:data)
    end

    if reached_max_drafts_per_user?(params)
      render_json_error I18n.t("draft.too_many_drafts.title"),
                        status: 403,
                        extras: {
                          description:
                            I18n.t(
                              "draft.too_many_drafts.description",
                              base_url: Discourse.base_url,
                            ),
                        }
      return
    end

    sequence =
      begin
        Draft.set(
          current_user,
          params[:draft_key],
          params[:sequence].to_i,
          params[:data],
          params[:owner],
          force_save: params[:force_save],
        )
      rescue Draft::OutOfSequence
        begin
          if !Draft.exists?(user_id: current_user.id, draft_key: params[:draft_key])
            Draft.set(
              current_user,
              params[:draft_key],
              DraftSequence.current(current_user, params[:draft_key]),
              params[:data],
              params[:owner],
            )
          else
            raise Draft::OutOfSequence
          end
        rescue Draft::OutOfSequence
          render_json_error I18n.t("draft.sequence_conflict_error.title"),
                            status: 409,
                            extras: {
                              description: I18n.t("draft.sequence_conflict_error.description"),
                            }
          return
        end
      end

    json = success_json.merge(draft_sequence: sequence)

    # check for conflicts when editing a post
    if data.present? && data["postId"].present? && data["action"].to_s.start_with?("edit")
      original_text = data["original_text"] || data["originalText"]
      original_title = data["original_title"]
      original_tags = data["original_tags"]

      if original_text.present?
        if post = Post.find_by(id: data["postId"])
          conflict = original_text != post.raw

          if post.post_number == 1
            conflict ||= original_title.present? && original_title != post.topic.title

            # Since the topic might have hidden tags the current editor can't see,
            # we need to check for conflicts even though there might not be any visible tags in the editor
            if !conflict
              original_tags = (original_tags || []).map(&:downcase).to_set
              current_tags = post.topic.tags.pluck(:name).to_set
              hidden_tags = DiscourseTagging.hidden_tag_names(@guardian).to_set
              conflict = original_tags != (current_tags - hidden_tags)
            end
          end

          if conflict
            conflict_user = BasicUserSerializer.new(post.last_editor, root: false)
            json.merge!(conflict_user:)
          end
        end
      end
    end

    render json: json
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

    begin
      Draft.clear(user, params[:id], params[:sequence].to_i)
    rescue Draft::OutOfSequence
      # nothing really we can do here, if try clearing a draft that is not ours, just skip it.
      # rendering an error causes issues in the composer
    rescue StandardError => e
      return render json: failed_json.merge(errors: e), status: 401
    end

    render json: success_json
  end

  private

  def reached_max_drafts_per_user?(params)
    user_id = current_user.id

    Draft.where(user_id: user_id).count >= SiteSetting.max_drafts_per_user &&
      !Draft.exists?(user_id: user_id, draft_key: params[:draft_key])
  end
end
