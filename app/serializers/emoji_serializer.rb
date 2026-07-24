# frozen_string_literal: true

class EmojiSerializer < ApplicationSerializer
  attributes :name, :url, :group, :created_by

  def created_by
    object.created_by
  end

  def url
    object.cdn_url
  end
end
