# frozen_string_literal: true

Migrations::Tooling::Schema.enum :site_setting_datatype do
  source { ::SiteSettings::TypeSupervisor.types }
end
