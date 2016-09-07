class WizardFieldChoiceSerializer < ApplicationSerializer
  attributes :id, :label, :data

  def id
    object.id
  end

  def label
    return object.label if object.label.present?

    # Try getting one from a translation
    field = object.field
    step = field.step
    I18n.t("wizard.step.#{step.id}.fields.#{field.id}.options.#{id}", default: id)
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
