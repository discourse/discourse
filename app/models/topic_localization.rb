# frozen_string_literal: true

class TopicLocalization < ActiveRecord::Base
  include LocaleMatchable

  belongs_to :topic

  validates :locale, presence: true, length: { maximum: 20 }
  validates :title, presence: true
  validates :fancy_title, presence: true
  validates :localizer_user_id, presence: true
  validates :locale, uniqueness: { scope: :topic_id }

  def update_excerpt(cooked: nil)
    return if cooked.blank?

    excerpt =
      Post.excerpt(
        cooked,
        SiteSetting.topic_excerpt_maxlength,
        strip_links: true,
        strip_images: true,
      )
    update_column(:excerpt, excerpt)
  end
end

# == Schema Information
#
# Table name: topic_localizations
#
#  id                :bigint           not null, primary key
#  topic_id          :integer          not null
#  locale            :string(20)       not null
#  title             :string           not null
#  fancy_title       :string           not null
#  localizer_user_id :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  excerpt           :string
#
# Indexes
#
#  index_topic_localizations_on_topic_id             (topic_id)
#  index_topic_localizations_on_topic_id_and_locale  (topic_id,locale) UNIQUE
#
