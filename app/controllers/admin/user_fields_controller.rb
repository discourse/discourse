class Admin::UserFieldsController < Admin::AdminController

  def self.columns
    [:name, :field_type, :editable, :description, :required, :show_on_profile]
  end

  def create
    field = UserField.new(params.require(:user_field).permit(*Admin::UserFieldsController.columns))
    field.required = params[:required] == "true"
    fetch_options(field)

    json_result(field, serializer: UserFieldSerializer) do
      field.save
    end
  end

  def index
    user_fields = UserField.all.includes(:user_field_options)
    render_serialized(user_fields, UserFieldSerializer, root: 'user_fields')
  end

  def update
    field_params = params.require(:user_field)

    field = UserField.where(id: params.require(:id)).first

    Admin::UserFieldsController.columns.each do |col|
      field.send("#{col}=", field_params[col] || false)
    end
    UserFieldOption.where(user_field_id: field.id).delete_all
    fetch_options(field)

    json_result(field, serializer: UserFieldSerializer) do
      field.save
    end
  end

  def destroy
    field = UserField.where(id: params.require(:id)).first
    field.destroy if field.present?
    render nothing: true
  end


  protected

    def fetch_options(field)
      options = params[:user_field][:options]
      if options.present?
        field.user_field_options_attributes = options.map {|o| {value: o} }.uniq
      end
    end
end

