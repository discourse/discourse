# frozen_string_literal: true

class RemoveCodefundSiteSettings < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name IN (
        'codefund_property_id',
        'codefund_advertiser_label',
        'codefund_advertiser_short_label',
        'codefund_through_trust_level',
        'codefund_nth_post',
        'codefund_display_advertiser_labels',
        'codefund_below_post_enabled',
        'codefund_above_post_stream_enabled',
        'codefund_above_suggested_enabled',
        'codefund_top_of_topic_list_enabled'
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
