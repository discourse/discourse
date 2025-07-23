# frozen_string_literal: true

class DiscourseSolved::BeforeHeadClose
  attr_reader :controller

  def initialize(controller)
    @controller = controller
  end

  def html
    return "" if !controller.instance_of? TopicsController

    topic_view = controller.instance_variable_get(:@topic_view)
    topic = topic_view&.topic
    return "" if !topic
    # note, we have canonicals so we only do this for page 1 at the moment
    # it can get confusing to have this on every page and it should make page 1
    # a bit more prominent + cut down on pointless work

    return "" if SiteSetting.solved_add_schema_markup == "never"

    allowed =
      controller.guardian.allow_accepted_answers?(topic.category_id, topic.tags.pluck(:name))
    return "" if !allowed

    first_post = topic_view.posts&.first
    return "" if first_post&.post_number != 1

    question_json = {
      "@type" => "Question",
      "name" => topic.title,
      "text" => get_schema_text(first_post),
      "upvoteCount" => first_post.like_count,
      "answerCount" => 0,
      "datePublished" => topic.created_at,
      "author" => {
        "@type" => "Person",
        "name" => topic.user&.username,
        "url" => topic.user&.full_url,
      },
    }

    if accepted_answer = topic.solved&.answer_post
      question_json["answerCount"] = 1
      question_json[:acceptedAnswer] = {
        "@type" => "Answer",
        "text" => get_schema_text(accepted_answer),
        "upvoteCount" => accepted_answer.like_count,
        "datePublished" => accepted_answer.created_at,
        "url" => accepted_answer.full_url,
        "author" => {
          "@type" => "Person",
          "name" => accepted_answer.user&.username,
          "url" => accepted_answer.user&.full_url,
        },
      }
    else
      return "" if SiteSetting.solved_add_schema_markup == "answered only"
    end

    [
      '<script type="application/ld+json">',
      MultiJson
        .dump(
          "@context" => "http://schema.org",
          "@type" => "QAPage",
          "name" => topic&.title,
          "mainEntity" => question_json,
        )
        .gsub("</", "<\\/")
        .html_safe,
      "</script>",
    ].join("")
  end

  private

  def get_schema_text(post)
    post.excerpt(nil, keep_onebox_body: true).presence ||
      post.excerpt(nil, keep_onebox_body: true, keep_quotes: true)
  end
end
