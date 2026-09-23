# frozen_string_literal: true

class TopicEmbedAlias < ActiveRecord::Base
  belongs_to :topic_embed

  def self.key_attributes(url)
    url_key = TopicEmbed.embed_url_key(url)
    { url_key:, url_hash: Digest::SHA256.hexdigest(url_key) }
  end
end
