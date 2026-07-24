# frozen_string_literal: true

class DiscourseSolved::QuestionSchemaSerializer < ApplicationSerializer
  # attributes are camelCase as the Q&A schema spec requires it
  attributes :answerCount, :author, :dateModified, :datePublished, :name, :text, :upvoteCount

  def serializable_hash
    hash = { "@type" => "Question" }.merge(super)
    if accepted_answers.present?
      hash["acceptedAnswer"] = accepted_answers.map do |post|
        DiscourseSolved::AnswerSchemaSerializer.new(post, root: false).serializable_hash
      end
    end
    if suggested_answers.present?
      hash["suggestedAnswer"] = suggested_answers.map do |post|
        DiscourseSolved::AnswerSchemaSerializer.new(post, root: false).serializable_hash
      end
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
    accepted_answers.to_a.size + suggested_answers.to_a.size
  end

  def datePublished
    object.created_at
  end

  def dateModified
    object.first_post&.last_version_at || object.created_at
  end

  def author
    { "@type" => "Person", "name" => object.user&.username, "url" => object.user&.full_url }
  end

  private

  def accepted_answers
    options[:accepted_answers]
  end

  def suggested_answers
    options[:suggested_answers]
  end
end
