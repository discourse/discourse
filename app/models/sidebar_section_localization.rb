# frozen_string_literal: true

class SidebarSectionLocalization < ActiveRecord::Base
  include LocaleMatchable

  belongs_to :sidebar_section

  validates :locale, presence: true, length: { maximum: 20 }
  validates :title, presence: true, length: { maximum: SidebarSection::MAX_TITLE_LENGTH }
  validates :sidebar_section_id, uniqueness: { scope: :locale }
end

# == Schema Information
#
# Table name: sidebar_section_localizations
#
#  id                 :bigint           not null, primary key
#  locale             :string(20)       not null
#  title              :string(30)       not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  sidebar_section_id :bigint           not null
#
# Indexes
#
#  idx_on_sidebar_section_id_locale_271bd8ee1c                (sidebar_section_id,locale) UNIQUE
#  index_sidebar_section_localizations_on_sidebar_section_id  (sidebar_section_id)
#
