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

  def fetch_html(topic:, accepted_answer:)
    question_json =
      DiscourseSolved::QuestionSchemaSerializer.new(
        topic,
        root: false,
        accepted_answer: accepted_answer,
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
