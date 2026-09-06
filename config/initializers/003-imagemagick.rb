# frozen_string_literal: true

# Point ImageMagick at Discourse's security policy (config/imagemagick/policy.xml).
# Child processes inherit this env var, so it covers every identify/magick/convert
# call. Refuse to boot if it points somewhere else, since overriding it would
# bypass the policy. Our own value is allowed (the app may boot more than once in
# a process tree, e.g. parallel test workers).
path = Rails.root.join("config/imagemagick").to_s

if ENV["MAGICK_CONFIGURE_PATH"] && ENV["MAGICK_CONFIGURE_PATH"] != path
  raise "MAGICK_CONFIGURE_PATH must not be set externally; Discourse manages it " \
          "to enforce its ImageMagick security policy (config/imagemagick/policy.xml)."
end

ENV["MAGICK_CONFIGURE_PATH"] = path
