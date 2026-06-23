# frozen_string_literal: true

require "safe_image"

SafeImage.configure!(backend: :vips, landlock: true)
