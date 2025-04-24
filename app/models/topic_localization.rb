# frozen_string_literal: true

class TopicLocalization < ActiveRecord::Base
  belongs_to :topic

  validates :locale, presence: true, length: { maximum: 20 }
  validates :title, presence: true
  validates :fancy_title, presence: true
  validates :localizer_user_id, presence: true
  validates :locale, uniqueness: { scope: :topic_id }

  def self.create_or_update!(topic_id:, locale:, title:, fancy_title:)
    localization = find_or_initialize_by(topic_id: topic_id, locale: locale)
    localization.title = title
    localization.fancy_title = fancy_title
    localization.save!
    localization
  end
end
