class Admin::UserFieldsController < Admin::AdminController

  def self.columns
    [:name, :field_type, :editable, :description, :required]
  end

  def create
    field = UserField.new(params.require(:user_field).permit(*Admin::UserFieldsController.columns))
    field.required = params[:required] == "true"
    json_result(field, serializer: UserFieldSerializer) do
      field.save
    end
  end

  def index
    render_serialized(UserField.all, UserFieldSerializer, root: 'user_fields')
  end

  def update
    field_params = params.require(:user_field)

    field = UserField.where(id: params.require(:id)).first

    Admin::UserFieldsController.columns.each do |col|
      field.send("#{col}=", field_params[col] || false)
    end

    json_result(field, serializer: UserFieldSerializer) do
      field.save
    end
  end

  def destroy
    field = UserField.where(id: params.require(:id)).first
    field.destroy if field.present?
    render nothing: true
  end

end

