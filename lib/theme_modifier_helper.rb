# frozen_string_literal: true
class ThemeModifierHelper
  def initialize(request: nil, theme_ids: nil)
    @theme_ids = theme_ids || request&.env&.[](:resolved_theme_ids)
  end

  ThemeModifierSet.modifiers.keys.each do |modifier|
    define_method(modifier) do
      Theme.lookup_modifier(@theme_ids, modifier)
    end
  end
end
