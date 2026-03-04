# frozen_string_literal: true

class DiscourseSolved::AnswerSchemaSerializer < ApplicationSerializer
  # attributes are camelCase as the Q&A schema spec requires it
  attributes :text, :upvoteCount, :datePublished, :url, :author

  def serializable_hash
    { "@type" => "Answer" }.merge(super)
  end

  def text
    object.excerpt(nil, keep_onebox_body: true).presence ||
      object.excerpt(nil, keep_onebox_body: true, keep_quotes: true)
  end

  def upvoteCount
    object.like_count
  end

  def datePublished
    object.created_at
  end

  def url
    object.full_url
  end

  def author
    { "@type" => "Person", "name" => object.user&.username, "url" => object.user&.full_url }
  end
end
