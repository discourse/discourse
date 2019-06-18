# frozen_string_literal: true

require 'benchmark/ips'
require File.expand_path('../../../../config/environment', __FILE__)

# set any flags here
# MiniRacer::Platform.set_flags! :noturbo

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
  [true, false].each do |sanitize|
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

# 27-07-2017 - Sam's NUC
#
# v8 5.7
#
#
# tiny post sanitize: true
#                         160.678  (±19.9%) i/s -    760.000  in   5.005630s
# giant post sanitize: true
#                         132.195  (±14.4%) i/s -    649.000  in   5.042695s
# most features sanitize: true
#                          56.205  (± 8.9%) i/s -    280.000  in   5.038138s
# lots of mentions sanitize: true
#                           0.318  (± 0.0%) i/s -      2.000  in   6.293644s
# tiny post sanitize: false
#                         404.304  (±20.8%) i/s -      1.920k in   5.019903s
# giant post sanitize: false
#                         327.721  (±11.9%) i/s -      1.624k in   5.033749s
# most features sanitize: false
#                          76.649  (±10.4%) i/s -    385.000  in   5.085552s
# lots of mentions sanitize: false
#                           0.306  (± 0.0%) i/s -      2.000  in   6.525968s
# markdown it no extensions commonmark tiny post
#                           5.871k (±19.1%) i/s -     28.544k in   5.073585s
# markdown it no extensions commonmark giant post
#                           1.006k (±12.5%) i/s -      4.960k in   5.041623s
# markdown it no extensions commonmark most features
#                           1.447k (± 8.9%) i/s -      7.205k in   5.029094s
# markdown it no extensions commonmark lots of mentions
#                           1.962k (± 8.3%) i/s -      9.850k in   5.061684s
#
#
# v8 5.9
#
#
# tiny post sanitize: true
#                         156.179  (±16.0%) i/s -    765.000  in   5.059401s
# giant post sanitize: true
#                         129.972  (±10.8%) i/s -    650.000  in   5.071824s
# most features sanitize: true
#                          54.960  (± 9.1%) i/s -    275.000  in   5.051284s
# lots of mentions sanitize: true
#                           0.321  (± 0.0%) i/s -      2.000  in   6.251009s
# tiny post sanitize: false
#                         431.159  (±10.4%) i/s -      2.166k in   5.085303s
# giant post sanitize: false
#                         300.236  (±11.7%) i/s -      1.479k in   5.029557s
# most features sanitize: false
#                          73.808  (±10.8%) i/s -    371.000  in   5.092310s
# lots of mentions sanitize: false
#                           0.297  (± 0.0%) i/s -      2.000  in   6.729708s
# markdown it no extensions commonmark tiny post
#                           6.421k (±13.0%) i/s -     32.012k in   5.084672s
# markdown it no extensions commonmark giant post
#                         901.622  (± 9.2%) i/s -      4.452k in   5.016748s
# markdown it no extensions commonmark most features
#                           1.410k (± 6.5%) i/s -      7.112k in   5.070053s
# markdown it no extensions commonmark lots of mentions
#                           1.934k (± 6.4%) i/s -      9.672k in   5.025858s
#
# v8 noturbo 5.9
#
#
# tiny post sanitize: true
#                         105.152  (±17.1%) i/s -    512.000  in   5.034419s
# giant post sanitize: true
#                          97.002  (±12.4%) i/s -    480.000  in   5.038382s
# most features sanitize: true
#                          46.355  (±12.9%) i/s -    228.000  in   5.009251s
# lots of mentions sanitize: true
#                           0.278  (± 0.0%) i/s -      2.000  in   7.205837s
# tiny post sanitize: false
#                         201.166  (±13.4%) i/s -    990.000  in   5.017725s
# giant post sanitize: false
#                         174.212  (±10.9%) i/s -    867.000  in   5.040859s
# most features sanitize: false
#                          60.272  (±14.9%) i/s -    295.000  in   5.029353s
# lots of mentions sanitize: false
#                           0.309  (± 0.0%) i/s -      2.000  in   6.483433s
# markdown it no extensions commonmark tiny post
#                           6.331k (±13.8%) i/s -     31.065k in   5.023613s
# markdown it no extensions commonmark giant post
#                           1.045k (± 9.6%) i/s -      5.208k in   5.053733s
# markdown it no extensions commonmark most features
#                           1.448k (± 6.7%) i/s -      7.239k in   5.024831s
# markdown it no extensions commonmark lots of mentions
#                           1.986k (± 5.2%) i/s -      9.990k in   5.044624s
