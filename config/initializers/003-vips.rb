# frozen_string_literal: true

if !Rails.env.production?
  begin
    require "vips"
    raise LoadError, "libvips 8.13 or newer is required" if !Vips.at_least_libvips?(8, 13)
  rescue LoadError => error
    raise LoadError, <<~MESSAGE, error.backtrace
            Discourse requires libvips for image processing, but it could not be loaded.

            Install libvips, then restart Discourse:
            https://github.com/libvips/libvips/wiki#building-and-installing
          MESSAGE
  end
end
