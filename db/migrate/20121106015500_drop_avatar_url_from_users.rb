# avatar_url does not function properly as it does not properly deal with scaling.
#   css based scaling is inefficient and has terrible results in both firefox and ie. canvas based scaling is slow.
#
#   for local urls we need to upload an image and have a pointer to the upload, then use the upload id in the user table
#   for gravatar we already have the email and can hash it

class DropAvatarUrlFromUsers < ActiveRecord::Migration
  def up
    remove_column :users, :avatar_url
  end

  def down
    add_column :users, :avatar_url, :string, null: false, default: ''
  end
end
