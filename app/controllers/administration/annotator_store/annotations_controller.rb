# https://github.com/thoughtbot/administrate/blob/master/app/controllers/administrate/application_controller.rb
#
class Administration::AnnotatorStore::AnnotationsController < Administration::ApplicationController


  def index
    scope = scoped_resource
    scope = scope.where(post_id: ::Topic.find(params[:topic_id]).post_ids) if params[:topic_id].present?
    scope = scope.where(post_id: params[:post_id]) if params[:post_id].present?
    scope = scope.where(creator_id: params[:creator_id]) if params[:creator_id].present?
    scope = scope.where(tag_id: params[:tag_id]) if params[:tag_id].present?

    search_term = params[:search].to_s.strip
    resources = Administrate::Search.new(scope, dashboard_class, search_term).run
    resources = resources.includes(*resource_includes) if resource_includes.any?
    resources = order.apply(resources)
    resources = resources.page(params[:page]).per(records_per_page)
    # page = Administrate::Page::Collection.new(dashboard, order: order)

    respond_to do |format|
      format.json { render json: JSON.pretty_generate(JSON.parse(resources.to_json))}
    end
  end


  def records_per_page
    params[:per_page] || 100
  end


end
