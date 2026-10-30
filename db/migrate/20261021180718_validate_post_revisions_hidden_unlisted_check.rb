# frozen_string_literal: true

class ValidatePostRevisionsHiddenUnlistedCheck < ActiveRecord::Migration[8.1]
  def up
    validate_check_constraint :post_revisions, name: "post_revisions_hidden_unlisted_exclusive"
  end

  def down
  end
end
