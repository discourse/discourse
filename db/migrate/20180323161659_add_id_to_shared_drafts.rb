# frozen_string_literal: true

class AddIdToSharedDrafts < ActiveRecord::Migration[5.1]
  def change
    add_column :shared_drafts, :id, :primary_key
  end
end
