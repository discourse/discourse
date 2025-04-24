# frozen_string_literal: true

class PostLocalization < ActiveRecord::Base
  belongs_to :post

  validates :post_version, presence: true
  validates :locale, presence: true, length: { maximum: 20 }
  validates :raw, presence: true
  validates :cooked, presence: true
  validates :localizer_user_id, presence: true
  validates :post_id, uniqueness: { scope: :locale }

  def self.create_or_update!(post_id:, post_version:, locale:, raw:, cooked:)
    localization = find_or_initialize_by(post_id: post_id, locale: locale)
    localization.post_version = post_version
    localization.raw = raw
    localization.cooked = cooked
    localization.save!
    localization
  end
end
