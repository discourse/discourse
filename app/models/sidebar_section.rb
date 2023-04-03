# frozen_string_literal: true

class SidebarSection < ActiveRecord::Base
  MAX_TITLE_LENGTH = 30

  belongs_to :user
  has_many :sidebar_section_links, -> { order("position") }, dependent: :destroy
  has_many :sidebar_urls,
           through: :sidebar_section_links,
           source: :linkable,
           source_type: "SidebarUrl"

  accepts_nested_attributes_for :sidebar_urls, allow_destroy: true

  validates :title,
            presence: true,
            uniqueness: {
              scope: %i[user_id],
            },
            length: {
              maximum: MAX_TITLE_LENGTH,
            }
end

# == Schema Information
#
# Table name: sidebar_sections
#
#  id         :bigint           not null, primary key
#  user_id    :integer          not null
#  title      :string(30)       not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public     :boolean          default(FALSE), not null
#
# Indexes
#
#  index_sidebar_sections_on_user_id_and_title  (user_id,title) UNIQUE
#
