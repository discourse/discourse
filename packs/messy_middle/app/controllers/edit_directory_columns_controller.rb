# frozen_string_literal: true

class EditDirectoryColumnsController < ApplicationController
  requires_login

  def index
    raise Discourse::NotFound unless guardian.is_staff?

    ensure_user_fields_have_columns

    columns = DirectoryColumn.includes(:user_field).all
    render_json_dump(directory_columns: serialize_data(columns, EditDirectoryColumnSerializer))
  end

  def update
    raise Discourse::NotFound unless guardian.is_staff?
    params.require(:directory_columns)
    directory_column_params = params.permit(directory_columns: {})
    directory_columns = DirectoryColumn.all

    has_enabled_column =
      directory_column_params[:directory_columns].values.any? do |column_data|
        column_data[:enabled].to_s == "true"
      end
    unless has_enabled_column
      raise Discourse::InvalidParameters, "Must have at least one column enabled"
    end

    directory_column_params[:directory_columns].values.each do |column_data|
      existing_column = directory_columns.detect { |c| c.id == column_data[:id].to_i }
      if (
           existing_column.enabled != column_data[:enabled] ||
             existing_column.position != column_data[:position].to_i
         )
        existing_column.update(enabled: column_data[:enabled], position: column_data[:position])
      end
    end

    render json: success_json
  end

  private

  def ensure_user_fields_have_columns
    user_fields_without_column =
      UserField
        .left_outer_joins(:directory_column)
        .where(directory_column: { user_field_id: nil })
        .where("show_on_profile=? OR show_on_user_card=?", true, true)

    return if user_fields_without_column.count <= 0

    next_position = DirectoryColumn.maximum("position") + 1

    new_directory_column_attrs = []
    user_fields_without_column.each do |user_field|
      new_directory_column_attrs.push(
        {
          user_field_id: user_field.id,
          enabled: false,
          type: DirectoryColumn.types[:user_field],
          position: next_position,
        },
      )

      next_position += 1
    end

    DirectoryColumn.insert_all(new_directory_column_attrs)
  end
end
