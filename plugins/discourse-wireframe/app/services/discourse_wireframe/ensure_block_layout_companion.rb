# frozen_string_literal: true

module DiscourseWireframe
  # Creates (or reuses) a local, editable theme component that owns block-layout
  # customizations for a parent theme that can't be published to directly — a
  # Git-managed theme, or a core system theme (Foundation, Horizon) — overlays the
  # supplied drafts onto it, and records the parent↔component mapping so the editor
  # recognizes the companion on re-entry.
  #
  # Because the component sits above its parent in the active stack
  # (`Theme.transform_ids` orders the parent first), the block-layout resolver
  # (most-derived wins) lets the component override the parent's outlets. The
  # component is local (no `remote_theme`), so it is not Git-managed and is
  # publishable.
  #
  # Lives in the plugin (not core `Themes::*`) because it establishes a persistent
  # editor-specific relationship — the companion — whose mapping is editor metadata.
  #
  # @example
  #   DiscourseWireframe::EnsureBlockLayoutCompanion.call(
  #     guardian: guardian,
  #     params: { theme_id: parent.id, drafts: [{ outlet_name:, layout_json: }] },
  #   )
  class EnsureBlockLayoutCompanion
    include Service::Base

    BLOCK_LAYOUTS_SUFFIX = "-block-layouts"

    params do
      attribute :theme_id, :integer
      attribute :drafts, :array, default: []

      # Allow negative ids: core system themes (Foundation, Horizon) have negative
      # ids and are a primary use case. `0` is never a real theme; existence is
      # enforced by the `model :theme` step.
      validates :theme_id, presence: true, numericality: { only_integer: true, other_than: 0 }
    end

    model :theme
    policy :current_user_is_admin
    step :validate_drafts

    transaction do
      step :ensure_component
      step :record_mapping
      step :overlay_drafts
    end

    step :build_result

    private

    def fetch_theme(params:)
      Theme.find_by(id: params.theme_id)
    end

    def current_user_is_admin(guardian:)
      guardian.is_admin?
    end

    # Bake-guard every draft up front so a malformed payload fails fast (422).
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

    # Reuse the recorded companion when one exists (so a rename never spawns a
    # duplicate); otherwise adopt a same-named local component child (legacy /
    # un-mapped), else create a fresh one — suffixing the name if the canonical
    # one is taken globally by something we can't reuse. Always link it as a child.
    def ensure_component(theme:, guardian:)
      component = find_existing_companion(theme) || create_companion(theme, guardian)
      theme.add_relative_theme!(:child, component) if theme.child_theme_ids.exclude?(component.id)
      context[:component] = component
    end

    def find_existing_companion(theme)
      mapped_id = DiscourseWireframe::BlockLayoutCompanion.companion_id_for(theme.id)
      return Theme.find(mapped_id) if mapped_id

      # No mapping yet (e.g. a companion created before mappings existed): adopt a
      # same-named local component child; `record_mapping` then stamps it.
      existing = Theme.find_by(name: "#{theme.name}#{BLOCK_LAYOUTS_SUFFIX}")
      existing if existing&.component? && existing.remote_theme&.is_git? != true
    end

    def create_companion(theme, guardian)
      base_name = "#{theme.name}#{BLOCK_LAYOUTS_SUFFIX}"
      name = Theme.find_by(name: base_name) ? Theme.uniquify_name(base_name) : base_name
      Theme.create!(name: name, component: true, user_id: guardian.user.id)
    end

    def record_mapping(theme:, component:)
      mapping =
        DiscourseWireframe::BlockLayoutCompanion.find_or_initialize_by(parent_theme_id: theme.id)
      mapping.update!(component_theme_id: component.id)
    end

    def overlay_drafts(params:, component:)
      normalized_drafts(params).each do |draft|
        component.set_field(
          target: :common,
          name: draft[:outlet_name],
          type: :block_layout,
          value: draft[:layout_json],
        )
      end
      component.save!
    end

    def build_result(component:)
      context[:theme_id] = component.id
    end

    # Normalize draft entries to symbol-keyed hashes, whether they arrive as
    # ActionController::Parameters (the controller) or plain hashes (specs). The
    # controller flattens the browser's positional-hash `drafts` encoding back to an
    # array before calling, so each entry here is a single draft.
    def normalized_drafts(params)
      params.drafts.to_a.map do |draft|
        draft.respond_to?(:to_unsafe_h) ? draft.to_unsafe_h.symbolize_keys : draft.symbolize_keys
      end
    end
  end
end
