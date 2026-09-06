# frozen_string_literal: true

class SidebarUrlLocalization < ActiveRecord::Base
  include LocaleMatchable

  belongs_to :sidebar_url

  validates :locale, presence: true, length: { maximum: 20 }
  validates :name, presence: true, length: { maximum: SidebarUrl::MAX_NAME_LENGTH }
  validates :sidebar_url_id, uniqueness: { scope: :locale }
end

# == Schema Information
#
# Table name: sidebar_url_localizations
#
#  id             :bigint           not null, primary key
#  locale         :string(20)       not null
#  name           :string(80)       not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  sidebar_url_id :bigint           not null
#
# Indexes
#
#  index_sidebar_url_localizations_on_sidebar_url_id             (sidebar_url_id)
#  index_sidebar_url_localizations_on_sidebar_url_id_and_locale  (sidebar_url_id,locale) UNIQUE
#
