# frozen_string_literal: true

module DiscourseWireframe
  # Creates a named, local theme component (a "design" in the editor's wording)
  # that owns block-layout customizations for the theme currently in use, overlays
  # the supplied drafts onto it, records the parent↔component mapping, and installs
  # it on the parent. Only one design is installed on a parent at a time, so any
  # previously installed design is unlinked (it stays available to switch back to).
  #
  # Because the component sits above its parent in the active stack
  # (`Theme.transform_ids` orders the parent first), the block-layout resolver
  # (most-derived wins) lets the component override the parent's outlets. The
  # component is local (no `remote_theme`), so it is not Git-managed and is
  # publishable — which is why this path works for core and Git parents alike.
  #
  # Lives in the plugin (not core `Themes::*`) because it establishes a persistent
  # editor-specific relationship whose mapping is editor metadata.
  #
  # @example
  #   DiscourseWireframe::EnsureBlockLayoutCompanion.call(
  #     guardian: guardian,
  #     params: { theme_id: parent.id, name: "Spring launch", drafts: [{ outlet_name:, layout_json: }] },
  #   )
  class EnsureBlockLayoutCompanion
    include Service::Base

    NAME_MAX_LENGTH = 100

    params do
      attribute :theme_id, :integer
      attribute :name, :string
      attribute :drafts, :array, default: []

      # Allow negative ids: core system themes (Foundation, Horizon) have negative
      # ids and are a primary use case. `0` is never a real theme; existence is
      # enforced by the `model :theme` step.
      validates :theme_id, presence: true, numericality: { only_integer: true, other_than: 0 }
      validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
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

    # Always creates a fresh component named by the admin (suffixed when the name
    # is taken), installs it on the parent, and unlinks the other designs so only
    # one is installed at a time.
    def ensure_component(theme:, guardian:, params:)
      name = params.name.strip
      name = Theme.uniquify_name(name) if Theme.exists?(name: name)
      component = Theme.create!(name: name, component: true, user_id: guardian.user.id)
      DiscourseWireframe::BlockLayoutCompanion.uninstall_all(theme)
      theme.add_relative_theme!(:child, component)
      context[:component] = component
    end

    def record_mapping(theme:, component:)
      DiscourseWireframe::BlockLayoutCompanion.create!(
        parent_theme_id: theme.id,
        component_theme_id: component.id,
      )
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
