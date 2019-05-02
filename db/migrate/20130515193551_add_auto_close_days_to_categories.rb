# frozen_string_literal: true

class AddAutoCloseDaysToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :auto_close_days, :float
  end
end
