# https://github.com/thoughtbot/administrate/blob/master/app/controllers/administrate/application_controller.rb
#
class Administration::AnnotatorStore::AnnotationsController < Administration::ApplicationController

  def index
    scope = scoped_resource
    scope = scope.where(post_id: ::Topic.find(params[:topic_id]).try(:post_ids)) if params[:topic_id].present?
    scope = scope.where(post_id: params[:post_id]) if params[:post_id].present?
    scope = scope.where(creator_id: params[:creator_id]) if params[:creator_id].present?

    # Only annotations where the posts topics are tagged with the given discourse tag.
    if params[:discourse_tag].present?
      if (tag = ::Tag.find_by(name: params[:discourse_tag]))
        scope = scope.where(post_id: Post.where(topic_id: tag.topic_ids).ids)
      else
        scope = scope.none
      end
    end

    # Only annotations that are tagged with the given Open Ethnographer tag.
    scope = scope.where(tag_id: params[:code_id]) if params[:code_id].present?

    search_term = params[:search].to_s.strip
    resources = Administrate::Search.new(scope, dashboard_class, search_term).run
    #resources = resources.includes(*resource_includes) if resource_includes.any?
    resources = order.apply(resources)
    resources = resources.page(params[:page]).per(records_per_page)
    page = Administrate::Page::Collection.new(dashboard, order: order)

    respond_to do |format|
      format.html { render locals: {resources: resources, search_term: search_term, page: page, show_search_bar: show_search_bar?} }

      format.json {
        # Rename tag_id to code_id
        r = resources.to_a.map(&:attributes).each { |a|  a['code_id'] = a.delete('tag_id') }
        render json: JSON.pretty_generate(JSON.parse(r.to_json) )
      }
    end
  end


  def records_per_page
    params[:per_page] || 100
  end


end
