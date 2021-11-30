# frozen_string_literal: true

class QueueInternalOneboxRebake < ActiveRecord::Migration[6.1]
  def up
    # Prior to this fix, internal oneboxes were bypassing the CDN for avatar URLs.
    # If a site has a CDN, queue up a rebake in the background
    if GlobalSetting.cdn_url
      execute <<~SQL
        UPDATE posts SET baked_version = 0
        WHERE cooked LIKE '%src="/user_avatar/%'
      SQL
    end
  end

  def down
    # Do nothing
  end
end
