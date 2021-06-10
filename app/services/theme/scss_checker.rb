class Theme
  class ScssChecker
    def initialize(target, theme_ids)
      @target = target
      @theme_ids = theme_ids
    end

    def has_scss(theme_id)
      !!get_themes_with_scss[theme_id]
    end

    private

    def get_themes_with_scss
      @themes_with_scss ||= begin
        theme_target = :mobile if @target == :mobile_theme
        theme_target = :desktop if @target == :desktop_theme
        name = @target == :embedded_theme ? :embedded_scss : :scss

        Theme
          .where(id: @theme_ids)
          .left_joins(:theme_fields)
          .where(theme_fields: {
            target_id: [Theme.targets[theme_target], Theme.targets[:common]],
            name: name
          })
          .group(:id)
          .size
      end
    end
  end
end
