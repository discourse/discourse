# frozen_string_literal: true

class UrlsInTopicTitleValidator < ActiveModel::Validator
  def validate(record)
    if UrlHelper.contains_url?(record.title) && !can_put_urls?(record)
      record.errors.add(:base, error_message)
    end
  end

  private

  def can_put_urls?(topic)
    guardian = Guardian.new(topic.acting_user)
    guardian.can_put_urls_in_topic_title?
  end

  def error_message
    I18n.t("urls_in_title_require_trust_level")
  end
end
