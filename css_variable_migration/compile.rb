# frozen_string_literal: true

# Compiles core, plugin and Horizon stylesheets for Foundation and Horizon in
# light and dark, and writes them with a manifest that lists the stylesheets
# each page loads, in order, for compare.mjs.
#
#   bin/rails runner css_variable_migration/compile.rb OUTPUT_DIR

output = ARGV.fetch(0)
FileUtils.mkdir_p(output)

# Horizon's stylesheets are read from the database, so import them from disk first
SystemThemesManager.sync!

def compile(output, name, asset, theme: nil, **options)
  css, _ =
    if theme
      theme.with_scss_load_paths do |load_paths|
        Stylesheet::Compiler.compile_asset(asset, theme_id: theme.id, load_paths:, **options)
      end
    else
      Stylesheet::Compiler.compile_asset(asset, options)
    end
  File.write(File.join(output, "#{name}.css"), css)
  $stderr.puts "compiled #{name}"
  "#{name}.css"
end

app = %w[common admin wizard].map { |target| compile(output, target, target) }
publish = compile(output, "publish", "publish")
embed = compile(output, "embed", "embed")

plugins =
  Discourse
    .find_plugin_css_assets(
      include_disabled: true,
      mobile_view: true,
      desktop_view: true,
      include_admin: true,
    )
    .map { |target| compile(output, "plugin-#{target}", target) }

foundation = Theme.find(Theme::CORE_THEMES["foundation"])
horizon = Theme.find(Theme::CORE_THEMES["horizon"])

horizon_files =
  %w[common_theme desktop_theme mobile_theme].map do |target|
    compile(
      output,
      "horizon-#{target}",
      target,
      theme: horizon,
      theme_variables: horizon.scss_variables.to_s,
    )
  end

profiles =
  {
    "foundation-light" => [foundation, foundation.color_scheme, []],
    "foundation-dark" => [foundation, foundation.dark_color_scheme, []],
    "horizon-light" => [horizon, horizon.color_scheme, horizon_files],
    "horizon-dark" => [horizon, horizon.dark_color_scheme, horizon_files],
  }.to_h do |name, (theme, scheme, theme_files)|
    colors =
      compile(
        output,
        "color_definitions-#{name}",
        "color_definitions",
        theme:,
        color_scheme_id: scheme&.id,
      )
    pages = {
      "app" => [colors, *app, *plugins, *theme_files],
      "publish" => [colors, publish, *theme_files, *plugins],
      "embed" => [embed],
    }
    [name, pages]
  end

File.write(File.join(output, "manifest.json"), JSON.pretty_generate(profiles))
