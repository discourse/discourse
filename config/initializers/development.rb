# frozen_string_literal: true

if Rails.env.development?
  Rails.application.reloader.to_prepare { ApplicationHelper::PLUGIN_OUTLET_TEMPLATE_CACHE.clear }
end
