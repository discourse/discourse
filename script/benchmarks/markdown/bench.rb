require 'benchmark/ips'
require File.expand_path('../../../../config/environment', __FILE__)


tests = [
  ["tiny post", "**hello**"],
  ["giant post", File.read("giant_post.md")],
  ["most features", File.read("most_features.md")],
  ["lots of mentions", File.read("lots_of_mentions.md")]
]

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
    tests.each do |test, text|
      x.report("#{test} sanitize: #{sanitize}") do
        PrettyText.markdown(text, sanitize: sanitize)
      end
    end
  end


  tests.each do |test, text|
    x.report("markdown it no extensions commonmark #{test}") do
      PrettyText.v8.eval("window.commonmark.render(#{text.inspect})")
    end
  end
end


# 18-07-2017 - Sam's NUC

# Calculating -------------------------------------
# tiny post sanitize: true
#                         162.766  (±13.5%) i/s -    812.000  in   5.101429s
# giant post sanitize: true
#                         133.957  (±11.2%) i/s -    663.000  in   5.029386s
# most features sanitize: true
#                          55.319  (±10.8%) i/s -    276.000  in   5.054290s
# lots of mentions sanitize: true
#                           0.313  (± 0.0%) i/s -      2.000  in   6.394343s
# tiny post sanitize: false
#                         456.209  (±13.6%) i/s -      2.288k in   5.117314s
# giant post sanitize: false
#                         331.357  (±10.9%) i/s -      1.650k in   5.046322s
# most features sanitize: false
#                          77.038  (±10.4%) i/s -    385.000  in   5.055062s
# lots of mentions sanitize: false
#                           0.312  (± 0.0%) i/s -      2.000  in   6.430657s
# markdown it no extensions commonmark tiny post
#                           6.916k (± 5.5%) i/s -     34.540k in   5.010354s
# markdown it no extensions commonmark giant post
#                           1.044k (± 9.3%) i/s -      5.247k in   5.090534s
# markdown it no extensions commonmark most features
#                           1.457k (± 5.0%) i/s -      7.314k in   5.034401s
# markdown it no extensions commonmark lots of mentions
#                           2.004k (± 5.2%) i/s -     10.192k in   5.100657s
# sam@ubuntu markdown %
#
