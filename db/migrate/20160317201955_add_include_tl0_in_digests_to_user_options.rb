# frozen_string_literal: true

class AddIncludeTl0InDigestsToUserOptions < ActiveRecord::Migration[4.2]
  def change
    add_column :user_options, :include_tl0_in_digests, :boolean, default: false
  end
end
