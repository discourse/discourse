# frozen_string_literal: true

Migrations::Database::Schema.enum :site_setting_datatype do
  source { ::SiteSettings::TypeSupervisor.types }
end
