# frozen_string_literal: true
class AddFormDataToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :form_data, :jsonb
  end
end
