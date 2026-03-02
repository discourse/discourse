# frozen_string_literal: true

class DiscourseSolved::BuildSchemaMarkup
  include Service::Base

  params { attribute :topic_id, :integer }

  model :topic
  policy :accepted_answers_allowed
  model :accepted_answer, optional: true
  policy :schema_markup_enabled
  step :build_html

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

  def build_html(topic:, accepted_answer:)
    question_json = build_question_json(topic)
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

  def build_question_json(topic)
    first_post = topic.first_post
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
