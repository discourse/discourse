# frozen_string_literal: true

class SidebarUrl < ActiveRecord::Base
  FULL_RELOAD_LINKS_REGEX = [%r{\A/my/[a-z_\-/]+\z}, %r{\A/safe-mode\z}]
  MAX_ICON_LENGTH = 40
  MAX_NAME_LENGTH = 80
  MAX_VALUE_LENGTH = 200
  COMMUNITY_SECTION_LINKS = [
    {
      id: -1,
      name: I18n.t("sidebar.sections.community.links.everything.content"),
      path: "/latest",
      icon: "layer-group",
      segment: "primary",
    },
    {
      id: -2,
      name: I18n.t("sidebar.sections.community.links.my_posts.content"),
      path: "/my/activity",
      icon: "user",
      segment: "primary",
    },
    {
      id: -3,
      name: I18n.t("sidebar.sections.community.links.review.content"),
      path: "/review",
      icon: "flag",
      segment: "primary",
    },
    {
      id: -4,
      name: I18n.t("sidebar.sections.community.links.admin.content"),
      path: "/admin",
      icon: "wrench",
      segment: "primary",
    },
    {
      id: -5,
      name: I18n.t("sidebar.sections.community.links.users.content"),
      path: "/u",
      icon: "users",
      segment: "secondary",
    },
    {
      id: -6,
      name: I18n.t("sidebar.sections.community.links.about.content"),
      path: "/about",
      icon: "info-circle",
      segment: "secondary",
    },
    {
      id: -7,
      name: I18n.t("sidebar.sections.community.links.faq.content"),
      path: "/faq",
      icon: "question-circle",
      segment: "secondary",
    },
    {
      id: -8,
      name: I18n.t("sidebar.sections.community.links.groups.content"),
      path: "/g",
      icon: "user-friends",
      segment: "secondary",
    },
    {
      id: -9,
      name: I18n.t("sidebar.sections.community.links.badges.content"),
      path: "/badges",
      icon: "certificate",
      segment: "secondary",
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

  def full_reload?
    FULL_RELOAD_LINKS_REGEX.any? { |regex| value =~ regex }
  end
end

# == Schema Information
#
# Table name: sidebar_urls
#
#  id         :bigint           not null, primary key
#  name       :string(80)       not null
#  value      :string(200)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  icon       :string(40)       not null
#  external   :boolean          default(FALSE), not null
#  segment    :string           default("primary"), not null
#
