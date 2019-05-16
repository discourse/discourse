# frozen_string_literal: true

class RenameNumFlagsToBlockNewUser < ActiveRecord::Migration[4.2]
  def up
    execute "update site_settings set name = 'num_spam_flags_to_block_new_user' where name = 'num_flags_to_block_new_user'"
  end

  def down
    execute "update site_settings set name = 'num_flags_to_block_new_user' where name = 'num_spam_flags_to_block_new_user'"
  end
end
