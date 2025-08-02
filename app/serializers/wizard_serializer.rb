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
    color_scheme ? color_scheme.colors_hashes : ColorScheme.base.colors_hashes
  end
end
