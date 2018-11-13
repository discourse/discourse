class WizardFieldSerializer < ApplicationSerializer

  attributes :id, :type, :required, :value, :label, :placeholder, :description,
             :overwritten_by
  has_many :choices, serializer: WizardFieldChoiceSerializer, embed: :objects

  FIELD_VALUE_FROM_SETTING = {
    "welcome" => "site_description"
  }

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
    if setting = FIELD_VALUE_FROM_SETTING[object.id]
      return SiteSetting.send(setting) || object.value
    end

    object.value
  end

  def include_value?
    overwritten || object.value.present?
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

  def overwritten_by
    FIELD_VALUE_FROM_SETTING[object.id]
  end

  def include_overwritten_by?
    overwritten
  end

  private

  def overwritten
    setting = FIELD_VALUE_FROM_SETTING[object.id]
    setting && SiteSetting.send(setting).present?
  end
end
