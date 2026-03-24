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
  end
end
