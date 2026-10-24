# frozen_string_literal: true
class AddFormDataChangesToPostRevisions < ActiveRecord::Migration[8.1]
  def change
    add_column :post_revisions, :form_data_changes, :jsonb
  end
end
