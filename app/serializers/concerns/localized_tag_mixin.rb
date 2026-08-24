# frozen_string_literal: true

# `name` is a display string and holds a localization when one applies, so the
# untranslated name rides along whenever the two differ.
module LocalizedTagMixin
  def self.included(klass)
    klass.attributes :name, :original_name, :description
  end

  def name
    @name ||= object.display_name(scope)
  end

  def description
    object.display_description(scope)
  end

  def original_name
    object.name
  end

  def include_original_name?
    name != object.name
  end
end
