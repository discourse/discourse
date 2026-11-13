# frozen_string_literal: true

# Regenerates config/appearance_styles/variables.json and
# palette_variables.json from the CSS core actually ships (not the SCSS
# sources), so AppearanceStyles::VariableRegistry knows every design variable,
# its type and where it is defined. Run it after changing core's design
# variables and review the diff:
#
#   bin/rails runner script/appearance_styles/build_variables.rb

require "json"

def walk(nodes, media, &block)
  nodes.each do |node|
    case node[:node]
    when :style_rule
      props = node[:children].select { |child| child[:node] == :property }
      yield node[:selector][:value], props, media
    when :at_rule
      next if node[:block].blank?
      prelude = Crass::Parser.stringify(node[:prelude]).strip
      walk(
        Crass::Parser.parse_rules(node[:block]),
        [media, "@#{node[:name]} #{prelude}"].compact.join(" "),
        &block
      )
    end
  end
end

def definitions(css, source)
  defs = []
  walk(Crass.parse(css), nil) do |selector, props, media|
    props.each do |prop|
      name = prop[:name]
      next if !name.start_with?("--")
      defs << {
        name: name,
        value: prop[:value],
        important: prop[:important],
        selector: selector,
        media: media,
        source: source,
      }
    end
  end
  defs
end

ROOT_SELECTORS = %w[:root html :root,html html,:root].freeze

def scope_for(defs)
  root = defs.any? { |d| ROOT_SELECTORS.include?(d[:selector].delete(" ")) && d[:media].nil? }
  root ? "root" : "scoped"
end

PALETTE_PREFIXES = %w[
  --primary
  --secondary
  --tertiary
  --quaternary
  --header_background
  --header_primary
  --highlight
  --danger
  --success
  --love
  --d-selected
  --d-hover
].freeze

def infer_type(name, value)
  nodes =
    begin
      AppearanceStyles::CssValue.parse(value)
    rescue AppearanceStyles::CssValue::ParseError
      return "unparseable"
    end
  flat = []
  AppearanceStyles::CssValue.each_node(nodes) { |n| flat << n }
  functions = flat.select { |n| n.type == :function }.map(&:value)
  idents = flat.select { |n| n.type == :ident }.map(&:value)
  dims = flat.select { |n| n.type == :dimension }
  top = nodes.reject { |n| n.type == :comma }

  colorish_var =
    flat.any? do |n|
      n.type == :function && n.value == "var" && n.children.first&.type == :ident &&
        PALETTE_PREFIXES.any? { |p| n.children.first.value.start_with?(p) }
    end
  color_fn = (functions & %w[rgb rgba hsl hsla light-dark color-mix oklch oklab]).any?

  return "shadow" if name.include?("shadow")
  if name.end_with?("-border") || name.end_with?("border-left") || name.end_with?("border-right") ||
       name.end_with?("border-top") || name.end_with?("border-bottom")
    return "border"
  end
  return "time" if dims.any? { |d| %w[s ms].include?(d.unit) } && top.size == 1
  if (functions & %w[cubic-bezier]).any? ||
       (idents & %w[ease ease-in ease-out ease-in-out linear]).any?
    return "easing"
  end
  return "font_weight" if name.include?("font-weight") || name.include?("weight")
  return "font_family" if name.include?("font-family")
  if colorish_var || color_fn || flat.any? { |n| n.type == :hash } ||
       name.match?(/color|background|-bg\b|bg-/)
    return "color"
  end
  if top.size == 1 &&
       (
         top.first.type == :dimension ||
           (top.first.type == :function && %w[calc min max clamp].include?(top.first.value)) ||
           (top.first.type == :number && top.first.value.zero?)
       )
    return "length"
  end
  return "number" if top.size == 1 && top.first.type == :number
  return "keyword" if top.size == 1 && top.first.type == :ident
  return "alias" if top.size == 1 && top.first.type == :function && top.first.value == "var"
  "compound"
end

sources = {}
core_common, = Stylesheet::Compiler.compile_asset(:common)
sources["core_common"] = core_common
core_colors, = Stylesheet::Compiler.compile_asset(:color_definitions)
sources["core_color_definitions"] = core_colors

core_defs = sources.flat_map { |source, css| definitions(css, source) }

design_names =
  core_defs
    .map { |d| d[:name] }
    .select { |n| n.start_with?("--d-", "--token-", "--hljs-") }
    .uniq
    .sort

inventory =
  design_names.map do |name|
    defs = core_defs.select { |d| d[:name] == name }
    root_def =
      defs.find { |d| ROOT_SELECTORS.include?(d[:selector].delete(" ")) && d[:media].nil? } ||
        defs.first
    {
      name: name,
      type: infer_type(name, root_def[:value]),
      scope: scope_for(defs),
      default: root_def[:value],
      selectors: defs.map { |d| [d[:selector], d[:media]].compact.join(" ") }.uniq.first(6),
    }
  end

# Resolve aliases (`--d-x: var(--d-y)`) to the type of what they point at.
by_name = inventory.index_by { |v| v[:name] }
inventory.each do |variable|
  next if variable[:type] != "alias"
  seen = Set.new
  current = variable
  while current && current[:type] == "alias" && seen.add?(current[:name])
    target = current[:default][/\Avar\((--[\w-]+)/, 1]
    if target && PALETTE_PREFIXES.any? { |p| target.start_with?(p) }
      current = { type: "color" }
      break
    end
    current = by_name[target]
  end
  alias_of = variable[:default][/\Avar\((--[\w-]+)/, 1]
  scale_alias = alias_of.to_s.start_with?("--space-", "--font-")
  variable[:type] = current ? current[:type] : (scale_alias ? "length" : "alias_unresolved")
end

palette_names =
  core_defs
    .map { |d| d[:name] }
    .select { |n| PALETTE_PREFIXES.any? { |p| n.start_with?(p) } }
    .uniq
    .sort

config_dir = Rails.root.join("config/appearance_styles")
File.write(config_dir.join("variables.json"), JSON.pretty_generate(inventory) + "\n")
File.write(config_dir.join("palette_variables.json"), JSON.pretty_generate(palette_names) + "\n")

puts "#{inventory.size} design variables, #{palette_names.size} palette variables"
