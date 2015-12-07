# order: after 02-freedom_patches.rb

require 'i18n/backend/discourse_i18n'
I18n.backend = I18n::Backend::DiscourseI18n.new
I18n.config.missing_interpolation_argument_handler = proc { throw(:exception) }
I18n.init_accelerator!

unless Rails.env.test?
  MessageBus.subscribe("/i18n-flush") { I18n.reload! }
end
