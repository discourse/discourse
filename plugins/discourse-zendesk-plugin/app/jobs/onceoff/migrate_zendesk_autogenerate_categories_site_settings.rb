# frozen_string_literal: true

module Jobs
  class MigrateZendeskAutogenerateCategoriesSiteSettings < ::Jobs::Onceoff
    def execute_onceoff(_)
      site_setting =
        SiteSetting.where(
          name: "zendesk_autogenerate_categories",
          data_type: SiteSettings::TypeSupervisor.types[:list],
        )

      return unless site_setting.exists?

      site_setting = site_setting.first

      site_setting.update!(
        data_type: SiteSettings::TypeSupervisor.types[:category_list],
        value: Category.where(name: site_setting.value.split("|")).pluck(:id).join("|"),
      )
    end
  end
end
