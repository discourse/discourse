class WizardFieldSerializer < ApplicationSerializer

  attributes :id, :type, :required, :value, :label, :placeholder, :description, :options

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

  def label
    I18n.t("#{i18n_key}.label", default: '')
  end

  def include_label?
    label.present?
  end

  def placeholder
    I18n.t("#{i18n_key}.placeholder", default: '')
  end

  def include_placeholder?
    placeholder.present?
  end

  def description
    I18n.t("#{i18n_key}.description", default: '')
  end

  def include_description?
    description.present?
  end

  def options
    object.options.map do |o|

      result = {id: o, label: I18n.t("#{i18n_key}.options.#{o}")}

      data = object.option_data[o]
      if data.present?
        as_json = data.dup
        as_json.delete(:id)
        result[:data] = as_json
      end

      result
    end
  end

  def include_options?
    object.options.present?
  end

end
