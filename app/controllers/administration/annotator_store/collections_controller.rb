class Administration::AnnotatorStore::CollectionsController < Administration::ApplicationController


  def create
    resource = resource_class.new(resource_params)
    resource.creator = current_user

    if resource.save
      redirect_to(
        [namespace, resource],
        notice: translate_with_resource("create.success"),
      )
    else
      render :new, locals: {
                   page: Administrate::Page::Form.new(dashboard, resource),
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
  #
  # Override this if you have certain roles that require a subset
  # this will be used to set the records shown on the `index` action.
  # def scoped_resource
  #  if current_user.super_admin?
  #    resource_class
  #  else
  #    resource_class.with_less_stuff
  #  end
  # end


end
