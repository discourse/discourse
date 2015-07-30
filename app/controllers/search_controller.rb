require_dependency 'search'

class SearchController < ApplicationController

  skip_before_filter :check_xhr, only: :show

  def self.valid_context_types
    %w{user topic category private_messages}
  end

  def show
    search = Search.new(params[:q], type_filter: 'topic', guardian: guardian, include_blurbs: true, blurb_length: 300)
    result = search.execute

    serializer = serialize_data(result, GroupedSearchResultSerializer, :result => result)

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

    search_args = {guardian: guardian}
    search_args[:type_filter] = params[:type_filter] if params[:type_filter].present?
    if params[:include_blurbs].present?
      search_args[:include_blurbs] = params[:include_blurbs] == "true"
    end
    search_args[:search_for_id] = true if params[:search_for_id].present?

    search_context = params[:search_context]
    if search_context.present?
      raise Discourse::InvalidParameters.new(:search_context) unless SearchController.valid_context_types.include?(search_context[:type])
      raise Discourse::InvalidParameters.new(:search_context) if search_context[:id].blank?

      # A user is found by username
      context_obj = nil
      if ['user','private_messages'].include? search_context[:type]
        context_obj = User.find_by(username_lower: params[:search_context][:id].downcase)
      else
        klass = search_context[:type].classify.constantize
        context_obj = klass.find_by(id: params[:search_context][:id])
      end

      if search_context[:type] == 'private_messages'
        search_args[:type_filter] = 'private_messages'
      end

      guardian.ensure_can_see!(context_obj)
      search_args[:search_context] = context_obj
    end

    search = Search.new(params[:term], search_args.symbolize_keys)
    result = search.execute
    render_serialized(result, GroupedSearchResultSerializer, :result => result)
  end

end
