# frozen_string_literal: true

class WizardSerializer < ApplicationSerializer
  attributes :start, :completed, :current_color_scheme

  has_many :steps, serializer: WizardStepSerializer, embed: :objects

  def start
    object.start.id
  end

  def completed
    object.completed?
  end

  def current_color_scheme
    color_scheme = Theme.where(id: SiteSetting.default_theme_id).first&.color_scheme
    colors = color_scheme ? color_scheme.colors : ColorScheme.base_colors

    # The frontend expects the color hexs to start with '#'
    colors_with_hash = {}
    colors.each { |color, hex| colors_with_hash[color] = "##{hex}" }
    colors_with_hash
  end
end
