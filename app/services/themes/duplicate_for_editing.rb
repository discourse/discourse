# frozen_string_literal: true

# Duplicates a whole theme into a new, editable, non-Git theme so its block
# layouts can be published from the editor (a Git-managed theme's live fields
# are never written — its outlets are read-only). The copy carries the user's
# current drafts overlaid on top, so no in-session work is lost.
#
# The whole theme is round-tripped through the existing export/import machinery
# (`ZipExporter` → `RemoteTheme.import_theme_from_directory`) rather than
# hand-copying fields, so SCSS/JS/locales/settings/color schemes/uploads all
# come along. A local (directory) import attaches a `remote_theme` with a blank
# `remote_url`, which is NOT Git-managed (`RemoteTheme#is_git?`), so the copy is
# publishable. The source's child components are re-linked onto the copy.
#
# @example
#   Themes::DuplicateForEditing.call(
#     guardian: guardian,
#     params: { theme_id: theme.id, drafts: [{ outlet_name:, layout_json: }] },
#   )
class Themes::DuplicateForEditing
  include Service::Base

  # @!method self.call(guardian:, params:)
  #   @param [Guardian] guardian
  #   @param [Hash] params
  #   @option params [Integer] :theme_id The id of the source theme to duplicate.
  #   @option params [Array] :drafts The edited outlets to overlay onto the copy,
  #     each `{ outlet_name:, layout_json: }`.
  #   @return [Service::Base::Context]

  params do
    attribute :theme_id, :integer
    attribute :drafts, :array, default: []

    validates :theme_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  end

  model :theme
  policy :current_user_is_admin
  policy :theme_is_duplicable
  step :validate_drafts
  # The export/import opens its own transaction and cleans up its temp files;
  # `try` turns an import or bake failure into a service failure (→ 422) instead
  # of an uncaught 500.
  try { step :duplicate_theme }

  step :relink_child_components
  step :build_result

  private

  def fetch_theme(params:)
    Theme.find_by(id: params.theme_id)
  end

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  # Allowed unless the theme opts out via the `duplicable_theme` modifier
  # (default NULL/true = duplicable; only an explicit `false` forbids it).
  def theme_is_duplicable(theme:)
    theme.theme_modifier_set&.duplicable_theme != false
  end

  # Bake-guard every draft up front so a malformed payload fails fast (422)
  # before any (relatively expensive) export/import work runs.
  def validate_drafts(params:)
    normalized_drafts(params).each do |draft|
      ThemeField.new(
        type_id: ThemeField.types[:block_layout],
        value: draft[:layout_json],
      ).bake_block_layout!
    rescue JSON::ParserError, RuntimeError => e
      fail!("Invalid draft for #{draft[:outlet_name]}: #{e.message}")
    end
  end

  # Normalize draft entries to symbol-keyed hashes, whether they arrive as
  # ActionController::Parameters (from the controller) or plain hashes (specs).
  def normalized_drafts(params)
    params.drafts.to_a.map do |draft|
      draft.respond_to?(:to_unsafe_h) ? draft.to_unsafe_h.symbolize_keys : draft.symbolize_keys
    end
  end

  def duplicate_theme(theme:, params:, guardian:)
    source = theme
    new_name = Theme.uniquify_name("#{source.name} (copy)")
    drafts = normalized_drafts(params)

    ThemeStore::ZipExporter
      .new(source)
      .with_export_dir do |dir|
        context[:new_theme] = RemoteTheme.import_theme_from_directory(
          dir,
          before_save: ->(theme_to_save) do
            theme_to_save.name = new_name
            theme_to_save.component = source.component
            theme_to_save.user_selectable = false
            theme_to_save.user_id = guardian.user.id
            drafts.each do |draft|
              theme_to_save.set_field(
                target: :common,
                name: draft[:outlet_name],
                type: :block_layout,
                value: draft[:layout_json],
              )
            end
          end,
        )
      end
  end

  # Re-link the source's child components onto the copy — `about.json` carries
  # no `components`, so the round-trip drops them. The same installed component
  # records are shared (no clone).
  def relink_child_components(theme:, new_theme:)
    theme.child_themes.each { |child| new_theme.add_relative_theme!(:child, child) }
  end

  def build_result(new_theme:)
    context[:theme_id] = new_theme.id
  end
end
