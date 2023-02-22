# frozen_string_literal: true

module DiscourseAutomation
  module PostExtension
    def self.prepended(base)
      base.class_eval { validate :discourse_automation_topic_required_words }
    end

    def discourse_automation_topic_required_words
      return if !SiteSetting.discourse_automation_enabled
      return if self.post_type == Post.types[:small_action]
      return if !topic
      return if topic.custom_fields[DiscourseAutomation::CUSTOM_FIELD].blank?

      topic.custom_fields[DiscourseAutomation::CUSTOM_FIELD].each do |automation_id|
        automation = DiscourseAutomation::Automation.find_by(id: automation_id)
        next if automation&.script != DiscourseAutomation::Scriptable::TOPIC_REQUIRED_WORDS

        words = automation.fields.find_by(name: "words")&.metadata["value"]
        next if words.blank?

        if words.none? { |word| raw.include?(word) }
          errors.add(
            :base,
            I18n.t(
              "discourse_automation.scriptables.topic_required_words.errors.must_include_word",
              words: words.join(", "),
            ),
          )
        end
      end
    end
  end
end
