class Admin::UserFieldsController < Admin::AdminController

  def self.columns
    [:name, :field_type, :editable, :description, :required, :show_on_profile, :position]
  end

  def create
    field = UserField.new(params.require(:user_field).permit(*Admin::UserFieldsController.columns))

    field.position = (UserField.maximum(:position) || 0) + 1
    field.required = params[:required] == "true"
    fetch_options(field)

    json_result(field, serializer: UserFieldSerializer) do
      field.save
    end
  end

  def index
    user_fields = UserField.all.includes(:user_field_options).order(:position)
    render_serialized(user_fields, UserFieldSerializer, root: 'user_fields')
  end

  def update
    field_params = params[:user_field]
    field = UserField.where(id: params.require(:id)).first

    Admin::UserFieldsController.columns.each do |col|
      unless field_params[col].nil?
        field.send("#{col}=", field_params[col])
      end
    end
    UserFieldOption.where(user_field_id: field.id).delete_all
    fetch_options(field)

    if field.save
      render_serialized(field, UserFieldSerializer, root: 'user_field')
    else
      render_json_error(field)
    end
  end

  def destroy
    field = UserField.where(id: params.require(:id)).first
    field.destroy if field.present?
    render json: success_json
  end

  protected

    def fetch_options(field)
      options = params[:user_field][:options]
      if options.present?
        field.user_field_options_attributes = options.map {|o| {value: o} }.uniq
      end
    end
end

