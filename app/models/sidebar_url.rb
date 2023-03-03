# frozen_string_literal: true

class SidebarUrl < ActiveRecord::Base
  validates :icon, presence: true, length: { maximum: 40 }
  validates :name, presence: true, length: { maximum: 80 }
  validates :value, presence: true, length: { maximum: 200 }

  validate :path_validator

  before_save :remove_internal_hostname, :set_external

  def path_validator
    if external?
      raise ActionController::RoutingError if value !~ Discourse::Utils::URI_REGEXP
    else
      Rails.application.routes.recognize_path(value)
    end
  rescue ActionController::RoutingError
    errors.add(
      :value,
      I18n.t("activerecord.errors.models.sidebar_section_link.attributes.linkable_type.invalid"),
    )
  end

  def remove_internal_hostname
    self.value =
      self
        .value
        .sub("http://#{Discourse.current_hostname}", "")
        .sub("https://#{Discourse.current_hostname}", "")
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
#  value      :string(200)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  icon       :string(40)       not null
#  external   :boolean          default(FALSE), not null
#
