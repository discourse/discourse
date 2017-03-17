module Jobs
  class MigrateCustomEmojis < Jobs::Onceoff
    def execute_onceoff(args)
      return if Rails.env.test?

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
            custom_emoji = CustomEmoji.new(name: name, upload: upload)

            if !custom_emoji.save
              warn("Failed to create custom emoji '#{name}': #{custom_emoji.errors.full_messages}")
            end
          else
            warn("Failed to create upload for '#{name}' custom emoji: #{upload.errors.full_messages}")
          end
        end
      end

      Emoji.clear_cache

      Post.where("cooked LIKE '%#{Emoji.base_url}%'").find_each do |post|
        post.rebake!
      end
    end

    def warn(message)
      Rails.logger.warn(message)
    end
  end
end
