# https://github.com/thoughtbot/administrate/blob/master/app/controllers/administrate/application_controller.rb
#
class Administration::AnnotatorStore::TagsController < Administration::ApplicationController


  def index
    scope = if api_request?
              scoped_resource
            else
              # Search or Tree view
              params[:search].present? ? scoped_resource.with_annotations_count : scoped_resource.with_annotations_count.where(ancestry: nil)
            end

    scope = scope.where(creator_id: params[:creator_id]) if params[:creator_id].present?

    search_term = params[:search].to_s.strip
    resources = Administrate::Search.new(scope, dashboard_class, search_term).run
    #resources = resources.includes(*resource_includes) if resource_includes.any?
    resources = params[:search].present? ? order.apply(resources) : resources.order('LOWER(name) asc')
    resources = resources.page(params[:page]).per(records_per_page)
    page = Administrate::Page::Collection.new(dashboard)

    respond_to do |format|
      format.html {render locals: {resources: resources, search_term: search_term, page: page, show_search_bar: show_search_bar?}}
      format.json {render json: JSON.pretty_generate(JSON.parse(resources.to_json))}
    end
  end


  def show
    respond_to do |format|
      format.html {render locals: {page: Administrate::Page::Show.new(dashboard, requested_resource)}}
      format.json {render json: JSON.pretty_generate(JSON.parse(requested_resource.to_json))}
    end
  end


  def create
    resource = resource_class.new(resource_params)
    resource.creator = current_user

    if resource.save
      redirect_to [namespace, resource], notice: 'Code was successfully created.'
    else
      render :new, locals: {page: Administrate::Page::Form.new(dashboard, resource)}
    end
  end


  def update
    if requested_resource.update(resource_params)
      if resource_params.include?(:merge_tag_id)
        redirect_to administration_annotator_store_tags_path, notice: 'Codes were successfully merged.'
      else
        redirect_to [namespace, requested_resource], notice: 'Code was successfully updated.'
      end
    else
      render :edit, locals: {page: Administrate::Page::Form.new(dashboard, requested_resource)}
    end
  end


  def destroy
    requested_resource.destroy
    flash[:notice] = 'Code was successfully destroyed.'
    redirect_to :back
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

  private

  def api_request?
    request.format.json? || request.format.xml?
  end

end
