# frozen_string_literal: true

require 'has_errors'

class Embedding < OpenStruct
  include HasErrors

  def self.settings
    %i(embed_by_username
       embed_post_limit
       embed_title_scrubber
       embed_truncate
       embed_whitelist_selector
       embed_blacklist_selector
       embed_classname_whitelist)
  end

  def base_url
    Discourse.base_url
  end

  def save
    Embedding.settings.each do |s|
      SiteSetting.set(s, public_send(s))
    end
    true
  rescue Discourse::InvalidParameters => p
    errors.add :base, p.to_s
    false
  end

  def embeddable_hosts
    EmbeddableHost.all.order(:host)
  end

  def self.find
    embedding_args = { id: 'default' }
    Embedding.settings.each { |s| embedding_args[s] = SiteSetting.get(s) }
    Embedding.new(embedding_args)
  end
end
