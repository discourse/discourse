# frozen_string_literal: true

# name: discourse-math
# about: Uses MathJax 4.1 or KaTeX to render math expressions.
# meta_topic_id: 65770
# version: 0.9
# authors: Sam Saffron (sam)
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-math

require "discourse_math_bundle"

register_asset "stylesheets/common/discourse-math.scss"
register_asset "stylesheets/ext/discourse-chat.scss"
register_svg_icon "square-root-variable"

enabled_site_setting :discourse_math_enabled

# Create symlinks to math library assets from the gem
plugin_public = File.join(__dir__, "public")
FileUtils.mkdir_p(plugin_public)

mathjax_link = File.join(plugin_public, "mathjax")
FileUtils.rm_f(mathjax_link) if File.symlink?(mathjax_link)
FileUtils.ln_s(DiscourseMathBundle.mathjax_path, mathjax_link)

katex_link = File.join(plugin_public, "katex")
FileUtils.rm_f(katex_link) if File.symlink?(katex_link)
FileUtils.ln_s(DiscourseMathBundle.katex_path, katex_link)

after_initialize do
  if respond_to?(:chat) && SiteSetting.chat_enabled
    chat&.enable_markdown_feature("discourse-math")
    chat&.enable_markdown_feature("math")
    chat&.enable_markdown_feature("asciimath") if SiteSetting.discourse_math_enable_asciimath
  end
end
