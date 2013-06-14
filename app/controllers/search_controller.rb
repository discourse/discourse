require_dependency 'search'

class SearchController < ApplicationController

  def self.valid_context_types
    %w{user topic category}
  end

  def query
    params.require(:term)

    search_args = {guardian: guardian}
    search_args[:type_filter] = params[:type_filter] if params[:type_filter].present?

    search_context = params[:search_context]
    if search_context.present?
      raise Discourse::InvalidParameters.new(:search_context) unless SearchController.valid_context_types.include?(search_context[:type])
      raise Discourse::InvalidParameters.new(:search_context) if search_context[:id].blank?

      klass = search_context[:type].classify.constantize

      # A user is found by username
      context_obj = nil
      if search_context[:type] == 'user'
        context_obj = klass.where(username_lower: params[:search_context][:id].downcase).first
      else
        context_obj = klass.where(id: params[:search_context][:id]).first
      end

      guardian.ensure_can_see!(context_obj)
      search_args[:search_context] = context_obj
    end

    search = Search.new(params[:term], search_args.symbolize_keys)
    render_json_dump(search.execute.as_json)
  end

end
