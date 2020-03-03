# frozen_string_literal: true
class ThemeFlagHelper
  def initialize(request: nil, theme_ids: nil)
    @theme_ids = theme_ids || request&.env&.[](:resolved_theme_ids)
  end

  ThemeFlagSet::FLAGS.keys.each do |flag|
    define_method(flag) do
      Theme.lookup_flag(@theme_ids, flag)
    end
  end
end
