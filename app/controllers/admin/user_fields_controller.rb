# frozen_string_literal: true

class Admin::UserFieldsController < Admin::AdminController
  def self.columns
    columns = %i[
      name
      field_type
      editable
      description
      requirement
      show_on_profile
      show_on_user_card
      position
      searchable
    ]
    DiscoursePluginRegistry.apply_modifier(:admin_user_fields_columns, columns)
  end

  def create
    field = UserField.new(params.require(:user_field).permit(*Admin::UserFieldsController.columns))

    field.position = (UserField.maximum(:position) || 0) + 1
    update_options(field)

    json_result(field, serializer: UserFieldSerializer) { field.save }
  end

  def index
    user_fields = UserField.all.includes(:user_field_options).order(:position)
    render_serialized(user_fields, UserFieldSerializer, root: "user_fields")
  end

  def show
    user_field = UserField.find(params[:id])
    render_serialized(user_field, UserFieldSerializer)
  end

  def edit
  end

  def update
    field_params = params[:user_field]
    field = UserField.where(id: params.require(:id)).first

    Admin::UserFieldsController.columns.each do |col|
      field.public_send("#{col}=", field_params[col]) unless field_params[col].nil?
    end
    update_options(field)

    if field.save
      if !field.show_on_profile && !field.show_on_user_card
        DirectoryColumn.where(user_field_id: field.id).destroy_all
      end
      render_serialized(field, UserFieldSerializer, root: "user_field")
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

  def update_options(field)
    options = params[:user_field][:options]
    if options.present?
      UserFieldOption.where(user_field_id: field.id).delete_all
      field.user_field_options_attributes = options.map { |o| { value: o } }.uniq
    end
  end
end
