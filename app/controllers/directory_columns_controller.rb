# frozen_string_literal: true

class DirectoryColumnsController < ApplicationController
  def index
    directory_columns = DirectoryColumn.includes(:user_field).where(enabled: true).order(:position)
    render_json_dump(directory_columns: serialize_data(directory_columns, DirectoryColumnSerializer))
  end
end
