# frozen_string_literal: true

# order: after 02-freedom_patches.rb

require 'i18n/backend/discourse_i18n'
require 'i18n/backend/fallback_locale_list'

I18n.backend = I18n::Backend::DiscourseI18n.new
I18n.fallbacks = I18n::Backend::FallbackLocaleList.new
I18n.config.missing_interpolation_argument_handler = proc { throw(:exception) }
I18n.reload!
I18n.init_accelerator!

unless Rails.env.test?
  MessageBus.subscribe("/i18n-flush") do
    I18n.reload!
    ExtraLocalesController.clear_cache!
  end
end
