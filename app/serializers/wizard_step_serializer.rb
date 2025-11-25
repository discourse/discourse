# frozen_string_literal: true

class WizardStepSerializer < ApplicationSerializer
  attributes :id, :title, :index, :emoji
  has_many :fields, serializer: WizardFieldSerializer, embed: :objects

  def id
    object.id
  end

  def index
    object.index
  end

  def i18n_key
    @i18n_key ||= "wizard.step.#{object.id}".underscore
  end

  def translate(sub_key, vars = nil)
    key = "#{i18n_key}.#{sub_key}"
    return nil unless I18n.exists?(key)

    vars.nil? ? I18n.t(key) : I18n.t(key, vars)
  end

  def title
    translate("title")
  end

  def include_title?
    title.present?
  end

  def emoji
    object.emoji
  end
end
