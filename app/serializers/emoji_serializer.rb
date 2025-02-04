# frozen_string_literal: true

class EmojiSerializer < ApplicationSerializer
  attributes :name, :url, :group, :created_by

  def created_by
    object.created_by
  end

  def url
    return nil if object.url.blank?
    Discourse.store.cdn_url(object.url)
  end
end
