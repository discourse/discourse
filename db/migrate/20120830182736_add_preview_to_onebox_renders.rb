# frozen_string_literal: true

class AddPreviewToOneboxRenders < ActiveRecord::Migration[4.2]
  def change
    add_column :onebox_renders, :preview, :text, null: true

    # Blow away the cache, so we can start saving previews too.
    execute "DELETE FROM onebox_renders"
    execute "DELETE FROM post_onebox_renders"
  end
end
