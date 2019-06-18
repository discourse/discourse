# frozen_string_literal: true

class ArchetypeSerializer < ApplicationSerializer

  attributes :id, :name, :options

  def options
    object.options.keys.collect do |k|
      {
        key: k,
        title: I18n.t("archetypes.#{object.id}.options.#{k}.title"),
        description: I18n.t("archetypes.#{object.id}.options.#{k}.description"),
        option_type: object.options[k]
      }
    end
  end

  def name
    I18n.t("archetypes.#{object.id}.title")
  end

end
