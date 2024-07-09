# frozen_string_literal: true

class RemoveCrossOriginUnsafeNoneReferrersSetting < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'cross_origin_opener_unsafe_none_referrers'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
