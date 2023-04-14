# frozen_string_literal: true

class SearchController < ApplicationController
  before_action :cancel_overloaded_search, only: [:query]
  skip_before_action :check_xhr, only: :show
  after_action :add_noindex_header

  def self.valid_context_types
    %w[user topic category private_messages tag]
  end

  def show
    permitted_params = params.permit(:q, :page)
    @search_term = permitted_params[:q]

    # a q param has been given but it's not in the correct format
    # eg: ?q[foo]=bar
    raise Discourse::InvalidParameters.new(:q) if params[:q].present? && !@search_term.present?

    if @search_term.present? && @search_term.length < SiteSetting.min_search_term_length
      raise Discourse::InvalidParameters.new(:q)
    end

    if @search_term.present? && @search_term.include?("\u0000")
      raise Discourse::InvalidParameters.new("string contains null byte")
    end

    page = permitted_params[:page]
    # check for a malformed page parameter
    raise Discourse::InvalidParameters if page && (!page.is_a?(String) || page.to_i.to_s != page)

    discourse_expires_in 1.minute

    search_args = {
      type_filter: "topic",
      guardian: guardian,
      blurb_length: 300,
      page: ([page.to_i, 1].max if page.to_i <= 10),
    }

    context, type = lookup_search_context
    if context
      search_args[:search_context] = context
      search_args[:type_filter] = type if type
    end

    search_args[:search_type] = :full_page
    search_args[:ip_address] = request.remote_ip
    search_args[:user_id] = current_user.id if current_user.present?

    if rate_limit_search
      return(
        render json: failed_json.merge(message: I18n.t("rate_limiter.slow_down")),
               status: :too_many_requests
      )
    elsif site_overloaded?
      result =
        Search::GroupedSearchResults.new(
          type_filter: search_args[:type_filter],
          term: @search_term,
          search_context: context,
        )

      result.error = I18n.t("search.extreme_load_error")
    else
      search = Search.new(@search_term, search_args)
      result = search.execute(readonly_mode: @readonly_mode)
      result.find_user_data(guardian) if result
    end

    serializer = serialize_data(result, GroupedSearchResultSerializer, result: result)

    respond_to do |format|
      format.html { store_preloaded("search", MultiJson.dump(serializer)) }
      format.json { render_json_dump(serializer) }
    end
  end

  def query
    params.require(:term)

    if params[:term].include?("\u0000")
      raise Discourse::InvalidParameters.new("string contains null byte")
    end

    discourse_expires_in 1.minute

    search_args = { guardian: guardian }

    search_args[:type_filter] = params[:type_filter] if params[:type_filter].present?
    search_args[:search_for_id] = true if params[:search_for_id].present?

    context, type = lookup_search_context

    if context
      search_args[:search_context] = context
      search_args[:type_filter] = type if type
    end

    search_args[:search_type] = :header
    search_args[:ip_address] = request.remote_ip
    search_args[:user_id] = current_user.id if current_user.present?
    search_args[:restrict_to_archetype] = params[:restrict_to_archetype] if params[
      :restrict_to_archetype
    ].present?

    if rate_limit_search
      return(
        render json: failed_json.merge(message: I18n.t("rate_limiter.slow_down")),
               status: :too_many_requests
      )
    elsif site_overloaded?
      result =
        GroupedSearchResults.new(
          type_filter: search_args[:type_filter],
          term: params[:term],
          search_context: context,
        )
    else
      search = Search.new(params[:term], search_args)
      result = search.execute(readonly_mode: @readonly_mode)
    end
    render_serialized(result, GroupedSearchResultSerializer, result: result)
  end

  def click
    params.require(:search_log_id)
    params.require(:search_result_type)
    params.require(:search_result_id)

    search_result_type = params[:search_result_type].downcase.to_sym
    if SearchLog.search_result_types.has_key?(search_result_type)
      attributes = { id: params[:search_log_id] }
      if current_user.present?
        attributes[:user_id] = current_user.id
      else
        attributes[:ip_address] = request.remote_ip
      end

      if search_result_type == :tag
        search_result_id = Tag.find_by_name(params[:search_result_id])&.id
      else
        search_result_id = params[:search_result_id]
      end

      SearchLog.where(attributes).update_all(
        search_result_type: SearchLog.search_result_types[search_result_type],
        search_result_id: search_result_id,
      )
    end

    render json: success_json
  end

  protected

  def site_overloaded?
    queue_time = request.env["REQUEST_QUEUE_SECONDS"]
    if queue_time
      threshold = GlobalSetting.disable_search_queue_threshold.to_f
      threshold > 0 && queue_time > threshold
    else
      false
    end
  end

  def rate_limit_search
    begin
      if current_user.present?
        RateLimiter.new(
          current_user,
          "search-min",
          SiteSetting.rate_limit_search_user,
          1.minute,
        ).performed!
      else
        RateLimiter.new(
          nil,
          "search-min-#{request.remote_ip}-per-sec",
          SiteSetting.rate_limit_search_anon_user_per_second,
          1.second,
        ).performed!
        RateLimiter.new(
          nil,
          "search-min-#{request.remote_ip}-per-min",
          SiteSetting.rate_limit_search_anon_user_per_minute,
          1.minute,
        ).performed!
        RateLimiter.new(
          nil,
          "search-min-anon-global-per-sec",
          SiteSetting.rate_limit_search_anon_global_per_second,
          1.second,
        ).performed!
        RateLimiter.new(
          nil,
          "search-min-anon-global-per-min",
          SiteSetting.rate_limit_search_anon_global_per_minute,
          1.minute,
        ).performed!
      end
    rescue RateLimiter::LimitExceeded => e
      return e
    end
    false
  end

  def cancel_overloaded_search
    render_json_error I18n.t("search.extreme_load_error"), status: 409 if site_overloaded?
  end

  def lookup_search_context
    return if params[:skip_context] == "true"

    search_context = params[:search_context]
    unless search_context
      if (context = params[:context]) && (id = params[:context_id])
        search_context = { type: context, id: id }
      end
    end

    if search_context.present?
      unless SearchController.valid_context_types.include?(search_context[:type])
        raise Discourse::InvalidParameters.new(:search_context)
      end
      raise Discourse::InvalidParameters.new(:search_context) if search_context[:id].blank?

      # A user is found by username
      context_obj = nil
      if %w[user private_messages].include? search_context[:type]
        context_obj = User.find_by(username_lower: search_context[:id].downcase)
      elsif "category" == search_context[:type]
        context_obj = Category.find_by(id: search_context[:id].to_i)
      elsif "topic" == search_context[:type]
        context_obj = Topic.find_by(id: search_context[:id].to_i)
      elsif "tag" == search_context[:type]
        context_obj = Tag.where_name(search_context[:name]).first
      end

      type_filter = nil
      type_filter = "private_messages" if search_context[:type] == "private_messages"

      guardian.ensure_can_see!(context_obj)

      [context_obj, type_filter]
    end
  end
end
