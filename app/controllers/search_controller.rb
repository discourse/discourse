require_dependency 'search'

class SearchController < ApplicationController

  skip_before_action :check_xhr, only: :show

  def self.valid_context_types
    %w{user topic category private_messages}
  end

  def show
    @search_term = params[:q]
    raise Discourse::InvalidParameters.new(:q) if @search_term.present? && @search_term.length < SiteSetting.min_search_term_length

    search_args = {
      type_filter: 'topic',
      guardian: guardian,
      include_blurbs: true,
      blurb_length: 300,
      page: if params[:page].to_i <= 10
              [params[:page].to_i, 1].max
            end
    }

    context, type = lookup_search_context
    if context
      search_args[:search_context] = context
      search_args[:type_filter] = type if type
    end

    search_args[:search_type] = :full_page
    search_args[:ip_address] = request.remote_ip
    search_args[:user_id] = current_user.id if current_user.present?

    search = Search.new(@search_term, search_args)
    result = search.execute

    result.find_user_data(guardian) if result

    serializer = serialize_data(result, GroupedSearchResultSerializer, result: result)

    respond_to do |format|
      format.html do
        store_preloaded("search", MultiJson.dump(serializer))
      end
      format.json do
        render_json_dump(serializer)
      end
    end
  end

  def query
    params.require(:term)

    search_args = { guardian: guardian }

    search_args[:type_filter] = params[:type_filter]                 if params[:type_filter].present?
    search_args[:include_blurbs] = params[:include_blurbs] == "true" if params[:include_blurbs].present?
    search_args[:search_for_id] = true                               if params[:search_for_id].present?

    context, type = lookup_search_context

    if context
      search_args[:search_context] = context
      search_args[:type_filter] = type if type
    end

    search_args[:search_type] = :header
    search_args[:ip_address] = request.remote_ip
    search_args[:user_id] = current_user.id if current_user.present?
    search_args[:restrict_to_archetype] = params[:restrict_to_archetype] if params[:restrict_to_archetype].present?

    search = Search.new(params[:term], search_args)
    result = search.execute
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
        search_result_id: search_result_id
      )
    end

    render json: success_json
  end

  protected

  def lookup_search_context

    return if params[:skip_context] == "true"

    search_context = params[:search_context]
    unless search_context
      if (context = params[:context]) && (id = params[:context_id])
        search_context = { type: context, id: id }
      end
    end

    if search_context.present?
      raise Discourse::InvalidParameters.new(:search_context) unless SearchController.valid_context_types.include?(search_context[:type])
      raise Discourse::InvalidParameters.new(:search_context) if search_context[:id].blank?

      # A user is found by username
      context_obj = nil
      if ['user', 'private_messages'].include? search_context[:type]
        context_obj = User.find_by(username_lower: search_context[:id].downcase)
      elsif 'category' == search_context[:type]
        context_obj = Category.find_by(id: search_context[:id].to_i)
      elsif 'topic' == search_context[:type]
        context_obj = Topic.find_by(id: search_context[:id].to_i)
      end

      type_filter = nil
      if search_context[:type] == 'private_messages'
        type_filter = 'private_messages'
      end

      guardian.ensure_can_see!(context_obj)

      [context_obj, type_filter]
    end
  end

end
