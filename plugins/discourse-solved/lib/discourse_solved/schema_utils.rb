# frozen_string_literal: true

module DiscourseSolved
  module SchemaUtils
    # Generates Schema.org microdata attributes for the crawler view of solved topics.
    #
    # Structure: QAPage > Question (mainEntity) > acceptedAnswer / suggestedAnswer
    #
    # - First post gets no schema (its content bubbles up to the Question scope)
    # - Ineligible replies (small actions, hidden, or textless onebox/image-only posts)
    #   get no schema attributes; the crawler view suppresses their microdata so nothing
    #   attaches to the surrounding Question scope
    # - The solved post is marked as acceptedAnswer, other replies as suggestedAnswer
    #
    # Spec: https://schema.org/QAPage
    # Validator: https://validator.schema.org/
    def self.schema_markup_enabled?(topic)
      return false unless Guardian.new.allow_accepted_answers?(topic)

      case SiteSetting.solved_add_schema_markup
      when "never"
        false
      when "answered only"
        accepted_answer_visible?(topic)
      else
        true
      end
    end

    def self.qa_page_schema?(topic)
      if topic.instance_variable_defined?(:@qa_page_schema)
        return topic.instance_variable_get(:@qa_page_schema)
      end
      topic.instance_variable_set(
        :@qa_page_schema,
        schema_markup_enabled?(topic) &&
          eligible_answers(topic).any? { |post| eligible_answer?(post) },
      )
    end

    def self.container_schema(topic)
      return nil unless qa_page_schema?(topic)
      { itemscope: true, itemtype: "https://schema.org/QAPage" }
    end

    def self.main_entity_schema(topic)
      return nil unless qa_page_schema?(topic)
      { itemprop: "mainEntity", itemscope: true, itemtype: "https://schema.org/Question" }
    end

    def self.post_schema(post, topic)
      return nil unless qa_page_schema?(topic)
      return { data: { qa_question: true } } if post.is_first_post?
      return {} unless eligible_answer?(post)
      if accepted_answer_visible?(topic) && topic.topic_answers.exists?(answer_post_id: post.id)
        { itemprop: "acceptedAnswer", itemscope: true, itemtype: "https://schema.org/Answer" }
      else
        { itemprop: "suggestedAnswer", itemscope: true, itemtype: "https://schema.org/Answer" }
      end
    end

    def self.post_answer_meta(post, topic)
      return unless post_schema(post, topic)&.[](:itemprop)
      "<meta itemprop='upvoteCount' content='#{post.like_count}'>" \
        "<meta itemprop='url' content='#{post.full_url}'>"
    end

    def self.main_entity_meta(topic, crawler_posts)
      return unless qa_page_schema?(topic)
      first_post = topic.first_post
      "<meta itemprop='answerCount' content='#{Array(crawler_posts).count { |p| eligible_answer?(p) }}'>" \
        "<meta itemprop='datePublished' content='#{topic.created_at.iso8601}'>" \
        "<meta itemprop='name' content='#{ERB::Util.html_escape(topic.title)}'>" \
        "<meta itemprop='upvoteCount' content='#{first_post&.like_count || 0}'>"
    end

    # Whether a post should be treated as an answer in schema output: a visible, regular,
    # non-first reply with real text content (excludes onebox/image/emoji-only posts).
    # Shared by the crawler microdata path and the JSON-LD service so both agree on what
    # counts as an answer.
    def self.eligible_answer?(post)
      !post.is_first_post? && post.post_type == Post.types[:regular] && !post.hidden &&
        post.cooked.present? && Nokogiri::HTML5.fragment(post.cooked).text.strip.present?
    end

    private_class_method def self.accepted_answer_visible?(topic)
      topic.solved&.answer_posts&.any? { |post| Guardian.new.can_see_post?(post) }
    end

    private_class_method def self.eligible_answers(topic)
      topic.posts.where.not(post_number: 1).where(post_type: Post.types[:regular], hidden: false)
    end
  end
end
