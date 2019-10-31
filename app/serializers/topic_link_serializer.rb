# frozen_string_literal: true

class TopicLinkSerializer < ApplicationSerializer

  attributes :url,
             :title,
             # :fancy_title,
             :internal,
             :attachment,
             :reflection,
             :clicks,
             :user_id,
             :domain,
             :root_domain,

  def attachment
    Discourse.store.has_been_uploaded?(object.url)
  end

  def include_user_id?
    object.user_id.present?
  end

  def root_domain
    MiniSuffix.domain(domain)
  end

end
