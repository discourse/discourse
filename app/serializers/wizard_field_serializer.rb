# frozen_string_literal: true

class WizardFieldSerializer < ApplicationSerializer
  attributes :id,
             :type,
             :required,
             :value,
             :label,
             :placeholder,
             :description,
             :extra_description,
             :icon,
             :disabled,
             :show_in_sidebar
  has_many :choices, serializer: WizardFieldChoiceSerializer, embed: :objects

  def id
    object.id
  end

  def type
    object.type
  end

  def required
    object.required
  end

  def value
    object.value
  end

  def include_value?
    object.value.present?
  end

  def i18n_key
    @i18n_key ||= "wizard.step.#{object.step.id}.fields.#{object.id}".underscore
  end

  def translate(sub_key, vars = nil)
    key = "#{i18n_key}.#{sub_key}"
    return nil unless I18n.exists?(key)

    vars.nil? ? I18n.t(key) : I18n.t(key, vars)
  end

  def label
    translate("label")
  end

  def include_label?
    label.present?
  end

  def placeholder
    translate("placeholder")
  end

  def include_placeholder?
    placeholder.present?
  end

  def description
    translate("description", base_path: Discourse.base_path)
  end

  def include_description?
    description.present?
  end

  def extra_description
    translate("extra_description", base_path: Discourse.base_path)
  end

  def include_extra_description?
    extra_description.present?
  end

  def icon
    object.icon
  end

  def include_icon?
    object.icon.present?
  end

  def disabled
    object.disabled
  end

  def include_disabled?
    object.disabled
  end

  def show_in_sidebar
    object.show_in_sidebar
  end

  def include_show_in_sidebar?
    object.show_in_sidebar.present?
  end

  def include_choices?
    object.type == "dropdown" || object.type == "radio"
  end
end
