# frozen_string_literal: true

class EmojisController < ApplicationController
  def index
    emojis = Emoji.allowed.group_by(&:group)
    render json: MultiJson.dump(emojis)
  end
end
