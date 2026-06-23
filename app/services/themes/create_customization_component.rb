# frozen_string_literal: true

# Creates (or reuses) a local, editable theme component that owns block-layout
# customizations for a parent theme that can't be published to directly — a
# Git-managed theme, or a core system theme (Foundation, Horizon) — then overlays
# the supplied drafts onto it. This is the light alternative to duplicating the
# whole theme: the parent stays untouched (and a Git parent keeps receiving
# upstream updates), while the customizations live in a `<name>-block-layouts`
# child component that CAN be published to.
#
# Because the component sits above its parent in the active stack
# (`Theme.transform_ids` orders the parent first), the block-layout resolver
# (most-derived wins) lets the component override the parent's outlets. The
# component is local (no `remote_theme`), so it is not Git-managed and is
# publishable.
#
# @example
#   Themes::CreateCustomizationComponent.call(
#     guardian: guardian,
#     params: { theme_id: parent.id, drafts: [{ outlet_name:, layout_json: }] },
#   )
class Themes::CreateCustomizationComponent
  include Service::Base

  BLOCK_LAYOUTS_SUFFIX = "-block-layouts"

  # @!method self.call(guardian:, params:)
  #   @param [Guardian] guardian
  #   @param [Hash] params
  #   @option params [Integer] :theme_id The id of the parent theme being customized.
  #   @option params [Array] :drafts The edited outlets to overlay onto the
  #     component, each `{ outlet_name:, layout_json: }`.
  #   @return [Service::Base::Context]

  params do
    attribute :theme_id, :integer
    attribute :drafts, :array, default: []

    # Allow negative ids: core system themes (Foundation, Horizon) have negative
    # ids and are a primary use case for a customization component (they can't be
    # published to directly). `0` is never a real theme. Existence is enforced by
    # the `model :theme` step below.
    validates :theme_id, presence: true, numericality: { only_integer: true, other_than: 0 }
  end

  model :theme
  policy :current_user_is_admin
  step :validate_drafts

  transaction do
    step :ensure_component
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

  # Look up (or create) the parent's local `<name>-block-layouts` component and
  # link it as a child. If the canonical name is taken by something we can't
  # reuse (a Git-imported component, a non-component theme), suffix it.
  def ensure_component(theme:, guardian:)
    base_name = "#{theme.name}#{BLOCK_LAYOUTS_SUFFIX}"
    existing = Theme.find_by(name: base_name)

    component =
      if existing&.component? && existing.remote_theme&.is_git? != true
        existing
      else
        name = existing.nil? ? base_name : Theme.uniquify_name(base_name)
        Theme.create!(name: name, component: true, user_id: guardian.user.id)
      end

    theme.add_relative_theme!(:child, component) if theme.child_theme_ids.exclude?(component.id)

    context[:component] = component
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
  # ActionController::Parameters (from the controller) or plain hashes (specs).
  def normalized_drafts(params)
    params.drafts.to_a.map do |draft|
      draft.respond_to?(:to_unsafe_h) ? draft.to_unsafe_h.symbolize_keys : draft.symbolize_keys
    end
  end
end
