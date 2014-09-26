class Admin::UserFieldsController < Admin::AdminController

  def create
    field = UserField.create!(params.require(:user_field).permit(:name, :field_type, :editable))
    render_serialized(field, UserFieldSerializer)
  end

  def index
    render_serialized(UserField.all, UserFieldSerializer, root: 'user_fields')
  end

  def update
    field_params = params.require(:user_field)

    field = UserField.where(id: params.require(:id)).first
    field.name = field_params[:name]
    field.field_type = field_params[:field_type]
    field.editable = field_params[:editable] == "true"
    field.save!

    render_serialized(field, UserFieldSerializer)
  end

  def destroy
    field = UserField.where(id: params.require(:id)).first
    field.destroy if field.present?
    render nothing: true
  end

end

