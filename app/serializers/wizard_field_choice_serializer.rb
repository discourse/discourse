class WizardFieldChoiceSerializer < ApplicationSerializer
  attributes :id, :label, :extra_label, :description, :icon, :data

  def id
    object.id
  end

  def i18nkey
    field = object.field
    step = field.step
    "wizard.step.#{step.id}.fields.#{field.id}.choices.#{id}"
  end

  def label
    return object.label if object.label.present?

    # Try getting one from a translation
    I18n.t("#{i18nkey}.label", default: id)
  end

  def extra_label
    object.extra_label
  end

  def include_extra_label?
    object.extra_label.present?
  end

  def description
    I18n.t("#{i18nkey}.description", default: "")
  end

  def include_description?
    description.present?
  end

  def icon
    object.icon
  end

  def include_icon?
    object.icon.present?
  end

  def data
    result = object.data.dup
    result.delete(:id)
    result
  end

  def include_data?
    object.data.present?
  end
end
