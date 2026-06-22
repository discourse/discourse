# frozen_string_literal: true

# Produces the repo-file representation of a single outlet's `block_layout` —
# `{ filename: "block_layouts/<outlet>.json", content: <pretty JSON> }` — so
# edit-driven tooling can download it and commit it to a theme's Git repository
# (the source of truth for a Git-managed theme, whose live field is never
# written here). Read-only: no transaction, no DB write.
#
# The source is the theme's live `block_layout` field value, unless the caller
# supplies a `layout_json` override (e.g. the current unpublished draft). Either
# way the JSON is validated by baking it, so a malformed payload is rejected
# (the controller maps it to HTTP 422) rather than emitting a broken file.
#
# @example
#   Themes::ExportBlockLayout.call(
#     guardian: guardian,
#     params: { theme_id: theme.id, outlet_name: "homepage-blocks" },
#   )
class Themes::ExportBlockLayout
  include Service::Base

  # @!method self.call(guardian:, params:)
  #   @param [Guardian] guardian
  #   @param [Hash] params
  #   @option params [Integer] :theme_id The id of the theme owning the outlet.
  #   @option params [String] :outlet_name The block outlet identifier.
  #   @option params [String] :layout_json Optional override to export instead of
  #     the live field (the serialized `{ schema_version, layout }` payload).
  #   @return [Service::Base::Context]

  params do
    attribute :theme_id, :integer
    attribute :outlet_name, :string
    attribute :layout_json, :string

    validates :theme_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :outlet_name, presence: true, format: { with: /\A[a-z0-9_:\-]+\z/ }
    validates :layout_json, length: { maximum: 1024**2 }, allow_nil: true
  end

  model :theme
  policy :current_user_is_admin
  model :source_value
  step :build_payload

  private

  def fetch_theme(params:)
    Theme.find_by(id: params.theme_id)
  end

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  # The JSON to export: the caller's override if given, otherwise the live
  # field's raw value. Returning nil (no override and no live field) trips
  # `on_model_not_found(:source_value)` → 404.
  def fetch_source_value(theme:, params:)
    return params.layout_json if params.layout_json.present?

    theme
      .theme_fields
      .where(
        name: params.outlet_name,
        target_id: Theme.targets[:common],
        type_id: ThemeField.types[:block_layout],
      )
      .pick(:value)
  end

  # Validate by baking (rejects malformed JSON → 422) and pretty-print the
  # canonical layout for Git-diff friendliness.
  def build_payload(params:, source_value:)
    canonical = ThemeField.new(type_id: ThemeField.types[:block_layout], value: source_value)
    context[:content] = JSON.pretty_generate(JSON.parse(canonical.bake_block_layout!))
    context[:filename] = "block_layouts/#{params.outlet_name}.json"
  rescue JSON::ParserError, RuntimeError => e
    fail!(e.message)
  end
end
