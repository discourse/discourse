# frozen_string_literal: true

module DiscourseSolved
  module SchemaUtils
    def self.schema_markup_enabled?(topic)
      return false unless Guardian.new.allow_accepted_answers?(topic)

      case SiteSetting.solved_add_schema_markup
      when "never"
        false
      when "answered only"
        topic.solved&.answer_post_id.present?
      else
        true
      end
    end

    def self.container_schema(topic)
      return nil if !schema_markup_enabled?(topic)
      { itemscope: true, itemtype: "https://schema.org/QAPage" }
    end

    def self.main_entity_schema(topic)
      return nil if !schema_markup_enabled?(topic)
      { itemprop: "mainEntity", itemscope: true, itemtype: "https://schema.org/Question" }
    end

    def self.post_schema(post, topic)
      return nil if !schema_markup_enabled?(topic)
      return {} if post.is_first_post?
      return { itemscope: true } if post.post_type == Post.types[:small_action]
      if topic.solved&.answer_post_id == post.id
        { itemprop: "acceptedAnswer", itemscope: true, itemtype: "https://schema.org/Answer" }
      else
        { itemprop: "suggestedAnswer", itemscope: true, itemtype: "https://schema.org/Answer" }
      end
    end
  end
end
