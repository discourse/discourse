# frozen_string_literal: true

class EmojiSerializer < ApplicationSerializer
  root 'emoji'
  attributes :name, :url
end
