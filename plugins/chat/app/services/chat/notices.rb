# frozen_string_literal: true

module Chat
  class Notices
    def self.groups_have_too_many_members_for_being_mentioned(groups)
      warning_text(
        single: "chat.mention_warning.too_many_members",
        multiple: "chat.mention_warning.too_many_members_multiple",
        first_identifier: groups.first.name,
        count: groups.count,
      )
    end

    private

    def self.warning_text(single:, multiple:, first_identifier:, count:)
      translation_key = count == 1 ? single : multiple
      I18n.t(translation_key, first_identifier: first_identifier, count: count - 1)
    end

    private_class_method :warning_text
  end
end
