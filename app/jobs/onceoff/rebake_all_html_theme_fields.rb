module Jobs
  class RebakeAllHtmlThemeFields < Jobs::Onceoff
    def execute_onceoff(args)
      ThemeField.where(type_id: ThemeField.types[:html]).find_each do |theme_field|
        theme_field.update(value_baked: nil)
      end

      Theme.clear_cache!
    end
  end
end
