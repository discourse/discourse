# frozen_string_literal: true

class DiscourseSolved::QuestionSchemaSerializer < ApplicationSerializer
  # attributes are camelCase as the Q&A schema spec requires it
  attributes :name, :text, :upvoteCount, :answerCount, :datePublished, :author

  def serializable_hash
    hash = { "@type" => "Question" }.merge(super)
    if accepted_answer.present?
      hash["acceptedAnswer"] = DiscourseSolved::AnswerSchemaSerializer.new(
        accepted_answer,
        root: false,
      ).serializable_hash
    end
    hash
  end

  def name
    object.title
  end

  def text
    first_post = object.first_post
    first_post.excerpt(nil, keep_onebox_body: true).presence ||
      first_post.excerpt(nil, keep_onebox_body: true, keep_quotes: true)
  end

  def upvoteCount
    object.first_post.like_count
  end

  def answerCount
    accepted_answer.present? ? 1 : 0
  end

  def datePublished
    object.created_at
  end

  def author
    { "@type" => "Person", "name" => object.user&.username, "url" => object.user&.full_url }
  end

  private

  def accepted_answer
    options[:accepted_answer]
  end
end
