# frozen_string_literal: true

class CategoryLocalization < ActiveRecord::Base
  belongs_to :category

  validates :locale, presence: true, length: { maximum: 20 }
  validates :name, presence: true, length: { maximum: 50 }
  validates :category_id, uniqueness: { scope: :locale }

  after_commit :invalidate_site_cache

  def invalidate_site_cache
    I18n.with_locale(locale) { Site.clear_cache }
  end
end

# == Schema Information
#
# Table name: category_localizations
#
#  id          :bigint           not null, primary key
#  category_id :bigint           not null
#  locale      :string(20)       not null
#  name        :string(50)       not null
#  description :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_category_localizations_on_category_id             (category_id)
#  index_category_localizations_on_category_id_and_locale  (category_id,locale) UNIQUE
#
