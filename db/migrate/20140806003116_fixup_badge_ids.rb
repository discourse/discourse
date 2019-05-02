# frozen_string_literal: true

class FixupBadgeIds < ActiveRecord::Migration[4.2]
  def change
    # badge ids were below 100, for user badges, this really messed stuff up
    # to resolve this add a "system" flag which we can use to figure out what
    # badges to bump
    add_column :badges, :system, :boolean, default: false, null: false
  end

end
