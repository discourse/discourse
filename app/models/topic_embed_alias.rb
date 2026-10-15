# frozen_string_literal: true

class TopicEmbedAlias < ActiveRecord::Base
  belongs_to :topic_embed

  def self.key_attributes(url)
    url_key = TopicEmbed.embed_url_key(url)
    { url_key:, url_hash: Digest::SHA256.hexdigest(url_key) }
  end
end

# == Schema Information
#
# Table name: topic_embed_aliases
#
#  id             :bigint           not null, primary key
#  url_hash       :string(64)       not null
#  url_key        :text             not null
#  topic_embed_id :bigint           not null
#
# Indexes
#
#  index_topic_embed_aliases_on_topic_embed_id  (topic_embed_id)
#  index_topic_embed_aliases_on_url_hash        (url_hash) UNIQUE
#
