require_dependency 'upload_creator'

class Admin::EmojisController < Admin::AdminController

  def index
    render_serialized(Emoji.custom, EmojiSerializer, root: false)
  end

  def create
    file = params[:file] || params[:files].first
    name = params[:name] || File.basename(file.original_filename, ".*")

    Scheduler::Defer.later("Upload Emoji") do
      # fix the name
      name = name.gsub(/[^a-z0-9]+/i, '_')
        .gsub(/_{2,}/, '_')
        .downcase

      upload = UploadCreator.new(
        file.tempfile,
        file.original_filename,
        type: 'custom_emoji'
      ).create_for(current_user.id)

      data =
        if upload.persisted?
          custom_emoji = CustomEmoji.new(name: name, upload: upload)

          if custom_emoji.save
            Emoji.clear_cache
            { name: custom_emoji.name, url: custom_emoji.upload.url }
          else
            failed_json.merge(errors: custom_emoji.errors.full_messages)
          end
        else
          failed_json.merge(errors: upload.errors.full_messages)
        end

      MessageBus.publish("/uploads/emoji", data.as_json, user_ids: [current_user.id])
    end

    render json: success_json
  end

  def destroy
    name = params.require(:id)

    # NOTE: the upload will automatically be removed by the 'clean_up_uploads' job
    CustomEmoji.find_by(name: name)&.destroy!

    Emoji.clear_cache

    Jobs.enqueue(:rebake_custom_emoji_posts, name: name)

    render json: success_json
  end

end
