# frozen_string_literal: true
#
class AddPotentiallyIllegalToReviewables < ActiveRecord::Migration[7.1]
  def change
    add_column :reviewables, :potentially_illegal, :boolean

    up_only do
      # NOTE: Only for records created after this migration. Trying to
      # apply this as part of adding the column will attempt to backfill
      # `false` into all existing reviewables. This is dangerous (locks
      # a potentially huge table) and will create some false negatives.
      #
      change_column_default :reviewables, :potentially_illegal, false
    end
  end
end
