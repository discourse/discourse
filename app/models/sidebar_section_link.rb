# frozen_string_literal: true

class SidebarSectionLink < ActiveRecord::Base
  belongs_to :user
  belongs_to :linkable, polymorphic: true
  belongs_to :sidebar_section

  validates :user_id, presence: true, uniqueness: { scope: %i[linkable_type linkable_id] }
  validates :linkable_id, presence: true
  validates :linkable_type, presence: true
  validate :ensure_supported_linkable_type, if: :will_save_change_to_linkable_type?

  SUPPORTED_LINKABLE_TYPES = %w[Category Tag SidebarUrl].freeze

  before_validation :inherit_user_id
  before_create do
    if self.user_id && self.sidebar_section
      self.position = self.sidebar_section.sidebar_section_links.maximum(:position).to_i + 1
    end
  end

  after_destroy { self.linkable.destroy! if self.linkable_type == "SidebarUrl" }

  private

  def inherit_user_id
    self.user_id = sidebar_section.user_id if sidebar_section
  end

  def ensure_supported_linkable_type
    if (!SUPPORTED_LINKABLE_TYPES.include?(self.linkable_type)) ||
         (self.linkable_type == "Tag" && !SiteSetting.tagging_enabled)
      self.errors.add(
        :linkable_type,
        I18n.t("activerecord.errors.models.sidebar_section_link.attributes.linkable_type.invalid"),
      )
    end
  end
end

# == Schema Information
#
# Table name: sidebar_section_links
#
#  id                 :bigint           not null, primary key
#  user_id            :integer          not null
#  linkable_id        :integer          not null
#  linkable_type      :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  sidebar_section_id :integer
#  position           :integer          default(0), not null
#
# Indexes
#
#  idx_sidebar_section_links_on_sidebar_section_id               (sidebar_section_id,user_id,position) UNIQUE
#  idx_unique_sidebar_section_links                              (user_id,linkable_type,linkable_id) UNIQUE
#  index_sidebar_section_links_on_linkable_type_and_linkable_id  (linkable_type,linkable_id)
#
