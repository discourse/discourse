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

begin
  plugin_public = File.join(__dir__, "public")
  FileUtils.mkdir_p(plugin_public)

  mathjax_link = File.join(plugin_public, "mathjax")
  mathjax_target = DiscourseMathBundle.mathjax_path
  if !File.symlink?(mathjax_link) || (File.readlink(mathjax_link) != mathjax_target)
    FileUtils.rm_f(mathjax_link)
    FileUtils.ln_s(mathjax_target, mathjax_link)
  end

  katex_link = File.join(plugin_public, "katex")
  katex_target = DiscourseMathBundle.katex_path
  if !File.symlink?(katex_link) || (File.readlink(katex_link) != katex_target)
    FileUtils.rm_f(katex_link)
    FileUtils.ln_s(katex_target, katex_link)
  end
rescue => e
  # the alternative of failing to boot is worse
  Discourse.warn_exception(e, message: "Failed to create symlinks for discourse-math assets")
end

after_initialize do
  if respond_to?(:chat) && SiteSetting.chat_enabled
    chat&.enable_markdown_feature("discourse-math")
    chat&.enable_markdown_feature("math")
    chat&.enable_markdown_feature("asciimath") if SiteSetting.discourse_math_enable_asciimath
  end
end
