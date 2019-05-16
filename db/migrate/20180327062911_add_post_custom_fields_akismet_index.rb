# frozen_string_literal: true

# This is our current pattern for data migrations needed by plugins, we prefer to keep them in core
# so schema is tightly controlled, especially if we are amending tables owned by core
#
# this index makes looking up posts requiring review much faster (20ms on meta)

class AddPostCustomFieldsAkismetIndex < ActiveRecord::Migration[5.1]
  def change
    add_index :post_custom_fields, [:post_id],
      name: 'idx_post_custom_fields_akismet',
      where: "name = 'AKISMET_STATE' AND value = 'needs_review'"
  end
end
