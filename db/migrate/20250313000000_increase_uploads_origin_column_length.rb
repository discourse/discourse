# frozen_string_literal: true
class IncreaseUploadsOriginColumnLength < ActiveRecord::Migration[7.2]
  def up
    change_column :uploads, :origin, :string, limit: 2000
  end

  def down
    change_column :uploads, :origin, :string, limit: 1000
  end
end
