# frozen_string_literal: true

class RenamePostImageSiteSettings < ActiveRecord::Migration[6.0]
  def up
    execute "UPDATE site_settings SET name = 'newuser_max_embedded_media' WHERE name = 'newuser_max_images'"
    execute "UPDATE user_histories SET subject = 'newuser_max_embedded_media' WHERE subject = 'newuser_max_images'"

    execute "UPDATE site_settings SET name = 'min_trust_to_post_embedded_media' WHERE name = 'min_trust_to_post_images'"
    execute "UPDATE user_histories SET subject = 'min_trust_to_post_embedded_media' WHERE subject = 'min_trust_to_post_images'"
  end

  def down
    execute "UPDATE site_settings SET name = 'newuser_max_images' WHERE name = 'newuser_max_embedded_media'"
    execute "UPDATE user_histories SET subject = 'newuser_max_images' WHERE subject = 'newuser_max_embedded_media'"

    execute "UPDATE site_settings SET name = 'min_trust_to_post_images' WHERE name = 'min_trust_to_post_embedded_media'"
    execute "UPDATE user_histories SET subject = 'min_trust_to_post_images' WHERE subject = 'min_trust_to_post_embedded_media'"
  end
end
