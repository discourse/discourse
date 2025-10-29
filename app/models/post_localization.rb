# frozen_string_literal: true

class PostLocalization < ActiveRecord::Base
  include LocaleMatchable

  belongs_to :post

  validates :post_version, presence: true
  validates :locale, presence: true, length: { maximum: 20 }
  validates :raw, presence: true
  validates :cooked, presence: true
  validates :localizer_user_id, presence: true
  validates :locale, uniqueness: { scope: :post_id }

  after_destroy :remove_search_index
  after_commit :enqueue_index_localization, on: %i[create update]

  private

  def enqueue_index_localization
    return unless SiteSetting.content_localization_enabled
    return if post_id.blank?

    # Enqueue background job to avoid blocking the request
    # This prevents performance issues during localization saves
    Jobs.enqueue(:index_post_localization_for_search, post_id: post_id)
  end

  def remove_search_index
    DB.exec(
      "DELETE FROM post_search_data WHERE post_id = :post_id AND locale = :locale",
      post_id: post_id,
      locale: locale,
    )
  end
end

# == Schema Information
#
# Table name: post_localizations
#
#  id                :bigint           not null, primary key
#  post_id           :integer          not null
#  post_version      :integer          not null
#  locale            :string(20)       not null
#  raw               :text             not null
#  cooked            :text             not null
#  localizer_user_id :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_post_localizations_on_post_id             (post_id)
#  index_post_localizations_on_post_id_and_locale  (post_id,locale) UNIQUE
#
