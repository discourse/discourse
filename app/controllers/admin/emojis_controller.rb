class Admin::EmojisController < Admin::AdminController

  def index
    render_serialized(Emoji.custom, EmojiSerializer, root: false)
  end

  def create
    file = params[:file] || params[:files].first
    name = params[:name] || File.basename(file.original_filename, ".*")

    # fix the name
    name = name.gsub(/[^a-z0-9]+/i, '_')
               .gsub(/_{2,}/, '_')
               .downcase

    if Emoji.exists?(name)
      render json: failed_json.merge(message: I18n.t("emoji.errors.name_already_exists", name: name)), status: 422
    else
      if emoji = Emoji.create_for(file, name)
        render_serialized(emoji, EmojiSerializer, root: false)
      else
        render json: failed_json.merge(message: I18n.t("emoji.errors.error_while_storing_emoji")), status: 422
      end
    end

  end

  def destroy
    name = params.require(:id)
    Emoji[name].try(:remove)
    render nothing: true
  end

end

