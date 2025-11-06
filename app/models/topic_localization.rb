# frozen_string_literal: true

class TopicLocalization < ActiveRecord::Base
  include LocaleMatchable

  belongs_to :topic

  validates :locale, presence: true, length: { maximum: 20 }
  validates :title, presence: true
  validates :fancy_title, presence: true
  validates :localizer_user_id, presence: true
  validates :locale, uniqueness: { scope: :topic_id }

  after_destroy :remove_search_index
  after_commit :reindex_topic_first_post, on: %i[create update]

  private

  def reindex_topic_first_post
    return unless SiteSetting.content_localization_enabled
    return if topic.blank?

    Scheduler::Defer.later "Reindex topic first post for localization" do
      # Reindex the first post which contains the topic title in search index
      first_post = topic.posts.find_by(post_number: 1)
      SearchIndexer.index(first_post) if first_post
    end
  end

  def remove_search_index
    return if topic_id.blank? || locale.blank?

    # Topics are not indexed separately in search, their first post contains the title
    # So we need to remove the localized version of the first post
    first_post = topic&.posts&.find_by(post_number: 1)
    if first_post
      DB.exec(
        "DELETE FROM post_search_data WHERE post_id = :post_id AND locale = :locale",
        post_id: first_post.id,
        locale: locale,
      )
    end
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
