# https://github.com/thoughtbot/administrate/blob/master/app/controllers/administrate/application_controller.rb
#
class Administration::AnnotatorStore::TagsController < Administration::ApplicationController


  def index
    scope = if params[:search].present?
              scoped_resource
            else
              # tree view
              s = resource_class.where(ancestry: nil)
              s = s.where(creator_id: params[:creator_id]) if params[:creator_id].present?
              s
            end

    search_term = params[:search].to_s.strip
    resources = Administrate::Search.new(scope,
                                         dashboard_class,
                                         search_term).run
    resources = resources.includes(*resource_includes) if resource_includes.any?
    resources = order.apply(resources)
    resources = resources.page(params[:page]).per(records_per_page)
    page = Administrate::Page::Collection.new(dashboard, order: order)

    render locals: {
             resources: resources,
             search_term: search_term,
             page: page,
             show_search_bar: show_search_bar?
           }
  end


  def create
    resource = resource_class.new(resource_params)
    resource.creator = current_user

    if resource.save
      redirect_to(
        [namespace, :annotator_store, resource],
        notice: 'Tag was successfully created.',
      )
    else
      render :new, locals: {
                   page: Administrate::Page::Form.new(dashboard, resource),
                 }
    end
  end


  def update
    if requested_resource.update(resource_params)
      redirect_to(
        [namespace, :annotator_store, requested_resource],
        notice: 'Tag was successfully updated.',
      )
    else
      render :edit, locals: {
                    page: Administrate::Page::Form.new(dashboard, requested_resource),
                  }
    end
  end


  # Overwrite any of the RESTful controller actions to implement custom behavior
  # For example, you may want to send an email after a foo is updated.
  #
  # def update
  #   foo = Foo.find(params[:id])
  #   foo.update(params[:foo])
  #   send_foo_updated_email
  # end

  # Override this method to specify custom lookup behavior.
  # This will be used to set the resource for the `show`, `edit`, and `update`
  # actions.
  #
  # def find_resource(param)
  #   Foo.find_by!(slug: param)
  # end


  def records_per_page
    params[:per_page] || 100
  end

end
