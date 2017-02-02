module Jobs
  class MigrateCustomEmojis < Jobs::Onceoff
    def execute_onceoff(args)
      return if Rails.env.test?

      CustomEmoji.transaction do
        Dir["#{Rails.root}/#{Emoji.base_directory}/*.{png,gif}"].each do |path|
          name = File.basename(path, File.extname(path))

          File.open(path) do |file|
            upload = Upload.create_for(
              Discourse.system_user.id,
              file,
              File.basename(path),
              file.size,
              image_type: 'custom_emoji'
            )

            if upload.persisted?
              CustomEmoji.create!(name: name, upload: upload)
            else
              raise "Failed to create upload for '#{name}' custom emoji"
            end
          end
        end

        Emoji.clear_cache

        Post.where("cooked LIKE '%#{Emoji.base_url}%'").find_each do |post|
          post.rebake!
        end
      end
    end
  end
end
