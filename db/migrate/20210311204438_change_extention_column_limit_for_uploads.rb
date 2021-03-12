# frozen_string_literal: true
class ChangeExtentionColumnLimitForUploads < ActiveRecord::Migration[6.0]
  def change
    change_column :uploads, :extension, :string, limit: 255
  end
end
