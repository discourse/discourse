require 'benchmark/ips'
require File.expand_path('../../../../config/environment', __FILE__)


tests = [
  ["tiny post", "**hello**"],
  ["giant post", File.read("giant_post.md")],
  ["most features", File.read("most_features.md")],
  ["lots of mentions", File.read("lots_of_mentions.md")]
]

SiteSetting.enable_experimental_markdown_it = true
PrettyText.cook("")
PrettyText.v8.eval("window.commonmark = window.markdownit('commonmark')")

# Benchmark.ips do |x|
#   x.report("markdown") do
#     PrettyText.markdown("x")
#   end
#
#   x.report("cook") do
#     PrettyText.cook("y")
#   end
# end
#
# exit

Benchmark.ips do |x|
  [true,false].each do |sanitize|
    {
      "markdown js" =>
        lambda{SiteSetting.enable_experimental_markdown_it = false},

      "markdown it" =>
        lambda{SiteSetting.enable_experimental_markdown_it = true}
    }.each do |name, before|
      before.call

      tests.each do |test, text|
        x.report("#{name} #{test} sanitize: #{sanitize}") do
          PrettyText.markdown(text, sanitize: sanitize)
        end
      end
    end
  end


  tests.each do |test, text|
    x.report("markdown it no extensions commonmark #{test}") do
      PrettyText.v8.eval("window.commonmark.render(#{text.inspect})")
    end
  end
end

