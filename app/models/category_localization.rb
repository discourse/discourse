# frozen_string_literal: true

class CategoryLocalization < ActiveRecord::Base
  include LocaleMatchable

  belongs_to :category

  validates :locale, presence: true, length: { maximum: 20 }
  validates :name, presence: true, length: { maximum: 50 }
  validates :category_id, uniqueness: { scope: :locale }

  after_commit :invalidate_site_cache

  def description_first_paragraph
    return if description.blank?

    @@first_paragraph_cache ||= LruRedux::ThreadSafeCache.new(1000)
    @@first_paragraph_cache.getset(description) do
      Category.first_paragraph_description(PrettyText.cook(description))
    end
  end

  def description_text
    first_paragraph = description_first_paragraph
    return if first_paragraph.blank?

    @@description_text_cache ||= LruRedux::ThreadSafeCache.new(1000)
    @@description_text_cache.getset(description) do
      ERB::Util.html_escape(Nokogiri::HTML5.fragment(first_paragraph).text.strip).html_safe
    end
  end

  def description_excerpt
    first_paragraph = description_first_paragraph
    return if first_paragraph.blank?

    @@description_excerpt_cache ||= LruRedux::ThreadSafeCache.new(1000)
    @@description_excerpt_cache.getset(description) { PrettyText.excerpt(first_paragraph, 300) }
  end

  def invalidate_site_cache
    I18n.with_locale(locale) { Site.clear_cache }
  end
end

# == Schema Information
#
# Table name: category_localizations
#
#  id          :bigint           not null, primary key
#  description :string(1000)
#  locale      :string(20)       not null
#  name        :string(50)       not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  category_id :bigint           not null
#
# Indexes
#
#  index_category_localizations_on_category_id             (category_id)
#  index_category_localizations_on_category_id_and_locale  (category_id,locale) UNIQUE
#
