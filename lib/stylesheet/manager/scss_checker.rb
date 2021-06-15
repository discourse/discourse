# frozen_string_literal: true

class Stylesheet::Manager::ScssChecker
  def initialize(target, theme_ids)
    @target = target.to_sym
    @theme_ids = theme_ids
  end

  def has_scss(theme_id)
    !!get_themes_with_scss[theme_id]
  end

  private

  def get_themes_with_scss
    @themes_with_scss ||= begin
      theme_target = @target.to_sym
      theme_target = :mobile if theme_target == :mobile_theme
      theme_target = :desktop if theme_target == :desktop_theme
      name = @target == :embedded_theme ? :embedded_scss : :scss

      results = Theme
        .where(id: @theme_ids)
        .left_joins(:theme_fields)
        .where(theme_fields: {
          target_id: [Theme.targets[theme_target], Theme.targets[:common]],
          name: name
        })
        .group(:id)
        .size

      results
    end
  end
end
