# frozen_string_literal: true

class SidebarUrl < ActiveRecord::Base
  validates :name, presence: true
  validates :value, presence: true
  validate :path_validator

  def path_validator
    Rails.application.routes.recognize_path(value)
  rescue ActionController::RoutingError
    errors.add(
      :value,
      I18n.t("activerecord.errors.models.sidebar_section_link.attributes.linkable_type.invalid"),
    )
  end
end

# == Schema Information
#
# Table name: sidebar_urls
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  value      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
