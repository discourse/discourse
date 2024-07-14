# frozen_string_literal: true

class RenameFlagsCustomTypeToRequireMessage < ActiveRecord::Migration[7.0]
  def change
    rename_column :flags, :custom_type, :require_message
  end
end
