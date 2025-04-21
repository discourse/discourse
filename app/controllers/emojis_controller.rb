# frozen_string_literal: true

class EmojisController < ApplicationController
  def index
    emojis = Emoji.allowed.group_by(&:group)
    render json: MultiJson.dump(emojis)
  end

  def search_aliases
    render json: MultiJson.dump(Emoji.search_aliases)
  end
end
