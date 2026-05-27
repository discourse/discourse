# frozen_string_literal: true

class DiscourseSolved::BuildSchemaMarkup
  include Service::Base

  params do
    attribute :post_ids, :array
    attribute :topic_id, :integer
    validates :topic_id, presence: true
  end

  model :topic
  policy :accepted_answers_allowed
  policy :schema_markup_enabled
  model :accepted_answer, optional: true
  model :suggested_answers, optional: true
  policy :has_answers
  model :html

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def accepted_answers_allowed(guardian:, topic:)
    guardian.allow_accepted_answers?(topic)
  end

  def schema_markup_enabled(topic:)
    DiscourseSolved::SchemaUtils.schema_markup_enabled?(topic)
  end

  def has_answers(accepted_answer:, suggested_answers:)
    accepted_answer.present? || suggested_answers.present?
  end

  def fetch_accepted_answer(topic:)
    post = topic.solved&.answer_post
    return unless post.present? && Guardian.new.can_see_post?(post)
    post if post.cooked.present? && Nokogiri::HTML5.fragment(post.cooked).text.strip.present?
  end

  def fetch_suggested_answers(params:, topic:, accepted_answer:)
    excluded_ids = [topic.first_post.id]
    excluded_ids << accepted_answer.id if accepted_answer.present?
    scope = topic.posts.where.not(id: excluded_ids)
    scope = scope.where(id: params.post_ids) if params.post_ids.present?
    scope
      .where(post_type: Post.types[:regular], hidden: false)
      .order(:post_number)
      .to_a
      .select { |p| p.cooked.present? && Nokogiri::HTML5.fragment(p.cooked).text.strip.present? }
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
          "datePublished" => topic.created_at,
          "mainEntity" => question_json,
        )
        .gsub("</", "<\\/")
        .html_safe

    "<script type=\"application/ld+json\">#{json}</script>"
  end
end
