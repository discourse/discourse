require_dependency 'search'

class SearchController < ApplicationController

  skip_before_filter :check_xhr, only: :show

  def self.valid_context_types
    %w{user topic category private_messages}
  end

  def show
    search_args = {
      type_filter: 'topic',
      guardian: guardian,
      include_blurbs: true,
      blurb_length: 300
    }

    context, type = lookup_search_context
    if context
      search_args[:search_context] = context
      search_args[:type_filter] = type if type
    end

    search = Search.new(params[:q], search_args)
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

    context,type = lookup_search_context
    if context
      search_args[:search_context] = context
      search_args[:type_filter] = type if type
    end

    search = Search.new(params[:term], search_args.symbolize_keys)
    result = search.execute
    render_serialized(result, GroupedSearchResultSerializer, result: result)
  end

  protected

  def lookup_search_context

    return if params[:skip_context] == "true"

    search_context = params[:search_context]
    unless search_context
      if (context = params[:context]) && (id = params[:context_id])
        search_context = {type: context, id: id}
      end
    end

    if search_context.present?
      raise Discourse::InvalidParameters.new(:search_context) unless SearchController.valid_context_types.include?(search_context[:type])
      raise Discourse::InvalidParameters.new(:search_context) if search_context[:id].blank?

      # A user is found by username
      context_obj = nil
      if ['user','private_messages'].include? search_context[:type]
        context_obj = User.find_by(username_lower: search_context[:id].downcase)
      else
        klass = search_context[:type].classify.constantize
        context_obj = klass.find_by(id: search_context[:id])
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
