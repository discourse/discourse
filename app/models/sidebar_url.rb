# frozen_string_literal: true

class SidebarUrl < ActiveRecord::Base
  include Localizable

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
      name: "My posts",
      path: "/my/activity",
      icon: "user",
      segment: SidebarUrl.segments["primary"],
    },
    {
      name: "My messages",
      path: "/my/messages",
      icon: "inbox",
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
    { name: "Filter", path: "/filter", icon: "filter", segment: SidebarUrl.segments["secondary"] },
  ]
  COMMUNITY_SECTION_LINK_PATHS = COMMUNITY_SECTION_LINKS.map { |link| link[:path] }.freeze

  validates :icon, presence: true, length: { maximum: MAX_ICON_LENGTH }
  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :value, presence: true, length: { maximum: MAX_VALUE_LENGTH }

  validate :path_validator

  accepts_nested_attributes_for :localizations, allow_destroy: true

  before_validation :remove_internal_hostname, :set_external
  before_validation :set_default_locale

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
    self.value = value.sub(%r{\Ahttp(s)?://#{Discourse.current_hostname}}, "")
  end

  def set_external
    self.external = value.start_with?("http://", "https://")
  end

  def set_default_locale
    self.locale ||= SiteSetting.default_locale.to_s
  end

  def self.built_in_community_section_link_value?(value)
    normalized_value =
      value.to_s.sub(%r{\Ahttps?://#{Regexp.escape(Discourse.current_hostname)}}, "")
    COMMUNITY_SECTION_LINK_PATHS.include?(normalized_value)
  end

  def built_in_community_section_link?
    self.class.built_in_community_section_link_value?(value)
  end
end

# == Schema Information
#
# Table name: sidebar_urls
#
#  id         :bigint           not null, primary key
#  external   :boolean          default(FALSE), not null
#  icon       :string(40)       not null
#  locale     :string(20)
#  name       :string(80)       not null
#  segment    :integer          default("primary"), not null
#  value      :string(1000)     not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
