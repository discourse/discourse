# frozen_string_literal: true

require "discourse_vips"

if !Rails.env.production?
  begin
    DiscourseVips.vips("version", operation: nil)
  rescue DiscourseVips::Error => error
    raise LoadError, <<~MESSAGE, error.backtrace
            Discourse requires libvips for image processing, but it could not be loaded.

            Install libvips, then restart Discourse:
            https://github.com/libvips/libvips/wiki#building-and-installing
          MESSAGE
  end
end
