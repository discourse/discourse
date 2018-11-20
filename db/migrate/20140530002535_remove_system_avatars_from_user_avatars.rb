# This takes all the system avatars out of the upload system, saving us a huge
# amount of space on backups
class RemoveSystemAvatarsFromUserAvatars < ActiveRecord::Migration[4.2]
  def up
    execute "UPDATE users SET uploaded_avatar_id = NULL WHERE uploaded_avatar_id IN (
      SELECT system_upload_id FROM user_avatars
    )"

    # normally we dont reach into the object model, but we have to here.
    # otherwise we will wait a real long time for uploads to go away
    skip = -1
    while skip = destroy_system_avatar_batch(skip) do
      puts "Destroyed up to id: #{skip}"
    end

    remove_column :user_avatars, :system_upload_id
    remove_column :user_avatars, :system_avatar_version
  end

  def destroy_system_avatar_batch(skip)
    initial = skip

    Upload.where('id IN (SELECT system_upload_id FROM user_avatars) AND id > ?', skip)
      .order(:id)
      .limit(500)
      .each do |upload|
      skip = upload.id
      begin
        upload.destroy
      rescue
        Rails.logger.warn "Could not destroy system avatar #{upload.id}"
      end
    end

    skip == initial ? nil : skip
  rescue
    Rails.logger.warn "Could not destroy system avatars, skipping"
    nil
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
