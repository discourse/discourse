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

      data = if Emoji.exists?(name)
        failed_json.merge(errors: [I18n.t("emoji.errors.name_already_exists", name: name)])
      elsif emoji = Emoji.create_for(file, name)
        emoji
      else
        failed_json.merge(errors: [I18n.t("emoji.errors.error_while_storing_emoji")])
      end

      MessageBus.publish("/uploads/emoji", data.as_json, user_ids: [current_user.id])
    end


    render json: success_json
  end

  def destroy
    name = params.require(:id)
    Emoji[name].try(:remove)
    render nothing: true
  end

end

