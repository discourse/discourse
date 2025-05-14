# frozen_string_literal: true

Rails.application.config.after_initialize do |config|
  if Rails.env.development?
    require "listen"

    listener =
      Listen.to("#{Rails.root}/themes") do
        Rails.logger.info "Theme folder changed. Syncing..."
        CoreThemesManager.sync!
      end
    listener.start
  end
end
