# frozen_string_literal: true

class AddUnlistedToPostRevisions < ActiveRecord::Migration[8.1]
  def change
    add_column :post_revisions, :unlisted, :boolean, default: false, null: false

    # Validated in a separate migration so the table scan doesn't run under this lock.
    add_check_constraint :post_revisions,
                         "NOT (hidden AND unlisted)",
                         name: "post_revisions_hidden_unlisted_exclusive",
                         validate: false
  end
end
