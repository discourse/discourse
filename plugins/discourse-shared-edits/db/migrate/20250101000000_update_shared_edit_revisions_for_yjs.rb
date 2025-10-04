# frozen_string_literal: true

class UpdateSharedEditRevisionsForYjs < ActiveRecord::Migration[8.0]
  def up
    # Change revision column from string to text to support larger Yjs state
    change_column :shared_edit_revisions, :revision, :text

    # Change raw column from string to text for consistency
    change_column :shared_edit_revisions, :raw, :text
  end

  def down
    # Revert back to string columns
    change_column :shared_edit_revisions, :revision, :string
    change_column :shared_edit_revisions, :raw, :string
  end
end
