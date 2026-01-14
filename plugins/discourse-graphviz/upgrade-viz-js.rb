# frozen_string_literal: true
# rubocop:disable Discourse/NoChdir
# rubocop:disable Discourse/Plugins/NamespaceMethods

version = ARGV[0]
if !version || version.empty?
  STDERR.puts "Please specify a version eg: 3.0.1"
  exit 1
end

link = "https://github.com/aduh95/viz.js/releases/download/v#{version}/viz.js.tar.gz"

require "tmpdir"

dest = File.expand_path(File.dirname(__FILE__), "public/javascripts/viz-#{version}.js")

def wrap_iife(contents)
  <<~JS
    var vizRenderStringSync;
    (function(module) {
    #{contents}
    vizRenderStringSync = module.exports;
    })({});
  JS
end

Dir.mktmpdir do |dir|
  Dir.chdir(dir) do
    `curl -L #{link} --output viz.js.tar.gz`
    `tar -xzvf viz.js.tar.gz`
    contents = File.read("package/dist/render_sync.js")
    File.write(dest, wrap_iife(contents))
  end
end

puts "#{dest} was written!"
