# frozen_string_literal: true

# name: discourse-math
# about: Uses MathJax 4.1 or KaTeX to render math expressions.
# meta_topic_id: 65770
# version: 0.9
# authors: Sam Saffron (sam)
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-math

require "discourse_math_bundle"
require_relative "lib/discourse_math/bundle_paths"

register_asset "stylesheets/common/discourse-math.scss"
register_asset "stylesheets/ext/discourse-chat.scss"
register_svg_icon "square-root-variable"

enabled_site_setting :discourse_math_enabled

begin
  DiscourseMath::BundlePaths.ensure_public_symlinks
rescue => e
  # the alternative of failing to boot is worse
  Discourse.warn_exception(e, message: "Failed to create symlinks for discourse-math assets")
end

after_initialize do
  add_to_serializer(:site, :discourse_math_bundle_url) do
    DiscourseMath::BundlePaths.public_url_base
  end

  if respond_to?(:chat) && SiteSetting.chat_enabled
    chat&.enable_markdown_feature("discourse-math")
    chat&.enable_markdown_feature("math")
    chat&.enable_markdown_feature("asciimath") if SiteSetting.discourse_math_enable_asciimath
  end
end
