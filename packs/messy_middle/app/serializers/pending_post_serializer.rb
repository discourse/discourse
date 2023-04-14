# frozen_string_literal: true

class PendingPostSerializer < ApplicationSerializer
  attributes :id,
             :avatar_template,
             :category_id,
             :created_at,
             :created_by_id,
             :name,
             :raw_text,
             :title,
             :topic_id,
             :topic_url,
             :username

  delegate :created_by, :payload, :topic, to: :object, private: true
  delegate :url, to: :topic, prefix: true, allow_nil: true
  delegate :avatar_template, :name, :username, to: :created_by, allow_nil: true

  def raw_text
    payload["raw"]
  end

  def title
    payload["title"] || topic.title
  end
end
