# frozen_string_literal: true

class DiscourseSolved::BuildSchemaMarkup
  include Service::Base

  def self.html_for(topic_id:, guardian:)
    call(params: { topic_id: topic_id }, guardian: guardian)[:html]
  end

  params { attribute :topic_id, :integer }

  step :setup
  model :topic
  policy :schema_markup_enabled
  policy :accepted_answers_allowed
  model :first_post
  model :accepted_answer, optional: true
  policy :has_answer_if_required
  step :build_html

  private

  def setup
    context[:html] = ""
  end

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def schema_markup_enabled
    SiteSetting.solved_add_schema_markup != "never"
  end

  def accepted_answers_allowed(guardian:, topic:)
    guardian.allow_accepted_answers?(topic)
  end

  def fetch_first_post(topic:)
    topic.first_post
  end

  def fetch_accepted_answer(topic:)
    topic.solved&.answer_post
  end

  def has_answer_if_required(accepted_answer:)
    return true if SiteSetting.solved_add_schema_markup != "answered only"
    accepted_answer.present?
  end

  def build_html(topic:, first_post:, accepted_answer:)
    question_json = build_question_json(topic, first_post)
    append_accepted_answer(question_json, accepted_answer) if accepted_answer

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

    context[:html] = "<script type=\"application/ld+json\">#{json}</script>"
  end

  def build_question_json(topic, first_post)
    {
      "@type" => "Question",
      "name" => topic.title,
      "text" => schema_text(first_post),
      "upvoteCount" => first_post.like_count,
      "answerCount" => 0,
      "datePublished" => topic.created_at,
      "author" => {
        "@type" => "Person",
        "name" => topic.user&.username,
        "url" => topic.user&.full_url,
      },
    }
  end

  def append_accepted_answer(question_json, accepted_answer)
    question_json["answerCount"] = 1
    question_json[:acceptedAnswer] = {
      "@type" => "Answer",
      "text" => schema_text(accepted_answer),
      "upvoteCount" => accepted_answer.like_count,
      "datePublished" => accepted_answer.created_at,
      "url" => accepted_answer.full_url,
      "author" => {
        "@type" => "Person",
        "name" => accepted_answer.user&.username,
        "url" => accepted_answer.user&.full_url,
      },
    }
  end

  def schema_text(post)
    post.excerpt(nil, keep_onebox_body: true).presence ||
      post.excerpt(nil, keep_onebox_body: true, keep_quotes: true)
  end
end
