# frozen_string_literal: true

class DiscourseSolved::BuildSchemaMarkup
  include Service::Base

  params do
    attribute :topic_id, :integer
    validates :topic_id, presence: true
  end

  model :topic
  policy :accepted_answers_allowed
  model :accepted_answer, optional: true
  policy :schema_markup_enabled
  model :suggested_answers, optional: true
  model :html

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def accepted_answers_allowed(guardian:, topic:)
    guardian.allow_accepted_answers?(topic)
  end

  def fetch_accepted_answer(topic:)
    topic.solved&.answer_post
  end

  def schema_markup_enabled(accepted_answer:)
    case SiteSetting.solved_add_schema_markup
    when "never"
      false
    when "answered only"
      accepted_answer.present?
    else
      true
    end
  end

  def fetch_suggested_answers(topic:, accepted_answer:)
    excluded_ids = [topic.first_post.id]
    excluded_ids << accepted_answer.id if accepted_answer.present?
    topic
      .posts
      .where.not(id: excluded_ids)
      .where(post_type: Post.types[:regular], hidden: false)
      .order(:post_number)
      .to_a
  end

  def fetch_html(topic:, accepted_answer:, suggested_answers:)
    question_json =
      DiscourseSolved::QuestionSchemaSerializer.new(
        topic,
        root: false,
        accepted_answer: accepted_answer,
        suggested_answers: suggested_answers,
      ).serializable_hash

    json =
      MultiJson
        .dump(
          "@context" => "http://schema.org",
          "@type" => "QAPage",
          "name" => topic.title,
          "mainEntity" => question_json,
        )
        .gsub("</", "<\\/")
        .html_safe

    "<script type=\"application/ld+json\">#{json}</script>"
  end
end
