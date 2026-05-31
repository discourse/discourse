# frozen_string_literal: true

class Admin::Config::DesignSystemController < Admin::AdminController
  ALLOWED_FILES = %w[colors fonts layout].freeze

  # The d-system top-level groups shown on each editor tab.
  FILE_GROUPS = {
    "colors" => %w[color],
    "fonts" => %w[font],
    "layout" => %w[layout radius space size],
  }.freeze

  DESIGN_SYSTEM_DIR = Rails.root.join("app/assets/stylesheets/common/design-system")

  def index
  end

  # Returns the design-system tokens for a tab as DTCG JSON, with each value
  # resolved to its concrete base value (e.g. {d-base.color.gray.0} -> #ffffff)
  # so the editor can display real values.
  def show
    render json: { content: resolved_tokens(fetch_file_name).to_json }
  end

  private

  def fetch_file_name
    file_name = params[:file_name]
    raise Discourse::InvalidParameters.new(:file_name) if ALLOWED_FILES.exclude?(file_name)
    file_name
  end

  def base_tokens
    @base_tokens ||= JSON.parse(File.read(DESIGN_SYSTEM_DIR.join("base.json")))
  end

  def system_tokens
    return @system_tokens if @system_tokens
    core = JSON.parse(File.read(DESIGN_SYSTEM_DIR.join("system.json")))
    overrides = active_theme_overrides
    @system_tokens = overrides.present? ? core.deep_merge("d-system" => overrides) : core
  end

  # The default theme's design-system.json overrides (rootless), merged so the
  # editor shows the values actually in effect on the site, not just core defaults.
  def active_theme_overrides
    theme = Theme.find_by(id: SiteSetting.default_theme_id)
    field =
      theme&.theme_fields&.find_by(target_id: Theme.targets[:design_system], name: "design-system")
    return {} if field.nil?

    JSON.parse(field.value)
  rescue JSON::ParserError
    {}
  end

  # Resolve a token whose $value references a base token ("{d-base.x.y}") to its
  # concrete base value, carrying the dark value too (base colors define both
  # light and dark). Literal values (e.g. layout dimensions) pass through.
  def resolve_token(node)
    value = node["$value"]
    match = value.is_a?(String) && value.match(/\A\{(.+)\}\z/)
    return node unless match

    base = match[1].split(".").reduce(base_tokens) { |acc, key| acc.is_a?(Hash) ? acc[key] : nil }
    return node unless base.is_a?(Hash) && base.key?("$value")

    resolved = node.merge("$value" => base["$value"])
    dark = base.dig("$extensions", "com.discourse.dark")
    resolved["$extensions"] = { "com.discourse.dark" => dark } if dark
    resolved
  end

  def deep_resolve(node)
    return node unless node.is_a?(Hash)
    return resolve_token(node) if node.key?("$value")

    node.transform_values { |child| deep_resolve(child) }
  end

  def resolved_tokens(file_name)
    system = system_tokens["d-system"] || {}
    groups =
      FILE_GROUPS[file_name].each_with_object({}) do |group, acc|
        acc[group] = deep_resolve(system[group]) if system[group]
      end
    { "d-system" => groups }
  end
end
