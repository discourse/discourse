# frozen_string_literal: true

module Chat
  class EmojisController < ::Chat::BaseController
    def index
      emojis = Emoji.all.group_by(&:group)
      render json: MultiJson.dump(emojis)
    end
  end
end
