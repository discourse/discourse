# frozen_string_literal: true

class Admin::EmojiController < Admin::AdminController
  def index
    render_serialized(Emoji.custom, EmojiSerializer, root: false)
  end

  # NOTE: This kind of custom logic also needs to be implemented to
  # be run in the ExternalUploadManager when a direct S3 upload is completed,
  # related to preventDirectS3Uploads in the UppyUploadMixin.
  #
  # Until then, preventDirectS3Uploads is set to true in the UppyUploadMixin.
  def create
    file = params[:file] || params[:files].first
    name = params[:name] || File.basename(file.original_filename, ".*")
    group = params[:group] ? params[:group].downcase : nil

    hijack do
      # fix the name
      name = File.basename(name, ".*")
      name = Emoji.sanitize_emoji_name(name)
      upload =
        UploadCreator.new(file.tempfile, file.original_filename, type: "custom_emoji").create_for(
          current_user.id,
        )

      good = true

      data =
        if upload.persisted?
          custom_emoji =
            CustomEmoji.new(name: name, upload: upload, group: group, user: current_user)

          if custom_emoji.save
            StaffActionLogger.new(current_user).log_custom_emoji_create(name, group: group)

            Emoji.clear_cache
            { name: custom_emoji.name, url: custom_emoji.upload.url, group: group }
          else
            good = false
            failed_json.merge(errors: custom_emoji.errors.full_messages)
          end
        else
          good = false
          failed_json.merge(errors: upload.errors.full_messages)
        end

      render json: data.as_json, status: good ? 200 : 422
    end
  end

  def destroy
    name = params.require(:id)

    # NOTE: the upload will automatically be removed by the 'clean_up_uploads' job
    emoji = CustomEmoji.find_by(name: name)

    if emoji.present?
      StaffActionLogger.new(current_user).log_custom_emoji_destroy(name)
      emoji.destroy!
    end

    Emoji.clear_cache

    Jobs.enqueue(:rebake_custom_emoji_posts, name: name)

    render json: success_json
  end
end
