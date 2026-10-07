# frozen_string_literal: true

require "discourse_vips"

if !Rails.env.production?
  Rails.application.config.after_initialize do
    next if !GlobalSetting.enable_vips_image_processing

    DiscourseVips.version
  rescue DiscourseVips::Error => error
    raise LoadError, <<~MESSAGE, error.backtrace
            Discourse requires libvips for image processing, but it could not be loaded.

            Install libvips, then restart Discourse:
            https://github.com/libvips/libvips/wiki#building-and-installing
          MESSAGE
  end
end
