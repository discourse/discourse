# frozen_string_literal: true

module Chat
  class EmojisController < ::Chat::BaseController
    def index
      emoji_deny_list = SiteSetting.emoji_deny_list

      if emoji_deny_list.present?
        denied_emojis = emoji_deny_list.split("|")
        emojis = Emoji.all.filter { |e| !denied_emojis.include?(e.name) }.group_by(&:group)
      else
        emojis = Emoji.all.group_by(&:group)
      end

      render json: MultiJson.dump(emojis)
    end
  end
end
