# frozen_string_literal: true

class SidebarUrl < ActiveRecord::Base
  enum :segment, { primary: 0, secondary: 1 }, scopes: false, suffix: true

  MAX_ICON_LENGTH = 40
  MAX_NAME_LENGTH = 80
  MAX_VALUE_LENGTH = 1000
  COMMUNITY_SECTION_LINKS = [
    {
      name: "Topics",
      path: "/latest",
      icon: "layer-group",
      segment: SidebarUrl.segments["primary"],
    },
    {
      name: "My Drafts",
      path: "/my/activity",
      icon: "far-pen-to-square",
      segment: SidebarUrl.segments["primary"],
    },
    { name: "Review", path: "/review", icon: "flag", segment: SidebarUrl.segments["primary"] },
    { name: "Admin", path: "/admin", icon: "wrench", segment: SidebarUrl.segments["primary"] },
    {
      name: "Invite",
      path: "/new-invite",
      icon: "paper-plane",
      segment: SidebarUrl.segments["primary"],
    },
    { name: "Users", path: "/u", icon: "users", segment: SidebarUrl.segments["secondary"] },
    {
      name: "About",
      path: "/about",
      icon: "circle-info",
      segment: SidebarUrl.segments["secondary"],
    },
    {
      name: "FAQ",
      path: "/faq",
      icon: "circle-question",
      segment: SidebarUrl.segments["secondary"],
    },
    { name: "Groups", path: "/g", icon: "user-group", segment: SidebarUrl.segments["secondary"] },
    {
      name: "Badges",
      path: "/badges",
      icon: "certificate",
      segment: SidebarUrl.segments["secondary"],
    },
  ]

  validates :icon, presence: true, length: { maximum: MAX_ICON_LENGTH }
  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :value, presence: true, length: { maximum: MAX_VALUE_LENGTH }

  validate :path_validator

  before_validation :remove_internal_hostname, :set_external

  def path_validator
    return true if !external?
    raise ActionController::RoutingError.new("Not Found") if value !~ Discourse::Utils::URI_REGEXP
  rescue ActionController::RoutingError
    errors.add(
      :value,
      I18n.t("activerecord.errors.models.sidebar_section_link.attributes.linkable_type.invalid"),
    )
  end

  def remove_internal_hostname
    self.value = self.value.sub(%r{\Ahttp(s)?://#{Discourse.current_hostname}}, "")
  end

  def set_external
    self.external = value.start_with?("http://", "https://")
  end
end

# == Schema Information
#
# Table name: sidebar_urls
#
#  id         :bigint           not null, primary key
#  name       :string(80)       not null
#  value      :string(1000)     not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  icon       :string(40)       not null
#  external   :boolean          default(FALSE), not null
#  segment    :integer          default("primary"), not null
#
