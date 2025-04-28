# frozen_string_literal: true

class PostLocalization < ActiveRecord::Base
  belongs_to :post

  validates :post_version, presence: true
  validates :locale, presence: true, length: { maximum: 20 }
  validates :raw, presence: true
  validates :cooked, presence: true
  validates :localizer_user_id, presence: true
  validates :locale, uniqueness: { scope: :post_id }
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
