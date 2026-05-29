# frozen_string_literal: true

# Saves a `block_layout` ThemeField for a single outlet on a theme.
#
# When the target theme is Git-imported (`remote_theme_id` is set), the save
# is *redirected* to a child theme component named
# `<theme-name>-customizations`. This component is created on the first save
# and reused thereafter, so admin-side edits land somewhere that won't be
# clobbered by upstream theme syncs.
#
# Pass `force_parent: true` to write directly to the parent (Git-imported)
# theme — used when a theme author is intentionally maintaining the upstream
# layout directly rather than through a child component.
#
# @example
#   Themes::SaveBlockLayout.call(
#     guardian: guardian,
#     params: {
#       theme_id: theme.id,
#       outlet_name: "homepage-blocks",
#       layout_json: layout.to_json,
#     }
#   )
#
class Themes::SaveBlockLayout
  include Service::Base

  CUSTOMIZATIONS_SUFFIX = "-customizations"

  # @!method self.call(guardian:, params:)
  #   @param [Guardian] guardian
  #   @param [Hash] params
  #   @option params [Integer] :theme_id The id of the theme being edited.
  #   @option params [String] :outlet_name The block outlet identifier
  #     (e.g. `"homepage-blocks"`). Stored as the ThemeField's `name`.
  #   @option params [String] :layout_json The serialized layout payload
  #     ({ schema_version, layout: [...] }). Validated structurally during
  #     baking; client-side full validation runs separately.
  #   @option params [Boolean] :force_parent Write to the parent theme even
  #     when it's Git-imported. Defaults to false (auto-redirect to a child).
  #   @return [Service::Base::Context] context whose `target_theme` is the
  #     theme that ended up holding the field, plus `redirected` /
  #     `child_created` flags so the client can surface the right notice.

  params do
    attribute :theme_id, :integer
    attribute :outlet_name, :string
    attribute :layout_json, :string
    attribute :force_parent, :boolean, default: false

    validates :theme_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :outlet_name, presence: true, format: { with: /\A[a-z0-9_:\-]+\z/ }
    validates :layout_json, presence: true, length: { maximum: 1024**2 }
  end

  model :theme
  policy :current_user_is_admin

  transaction do
    step :resolve_target_theme
    step :upsert_field
    step :save_target_theme
    step :reload_field
    step :guard_against_bake_error
  end

  step :publish_message_bus_update

  private

  def fetch_theme(params:)
    Theme.find_by(id: params.theme_id)
  end

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  # Decides which theme actually receives the field. If the requested theme
  # is Git-imported (`remote_theme_id` set) and the caller didn't opt into
  # `force_parent`, we redirect to a `<name>-customizations` child component
  # — creating it on the fly the first time. The context records both the
  # final target theme and the redirection flags so the controller can let
  # the client know what happened.
  def resolve_target_theme(theme:, params:)
    if theme.remote_theme_id.nil? || params.force_parent
      context[:target_theme] = theme
      context[:redirected] = false
      context[:child_created] = false
      return
    end

    target, created = ensure_customizations_component_for(theme)
    context[:target_theme] = target
    context[:redirected] = true
    context[:child_created] = created
  end

  # Idempotent lookup-or-create for the `<theme-name>-customizations` child
  # component. If a component with that exact name already exists but isn't
  # linked as a child of the parent theme, we link it before returning. If
  # the name is taken by something we can't reuse (a Git-imported component,
  # a non-component theme), we fall back to suffixing `-2`, `-3`, ... until
  # an unused name is available.
  def ensure_customizations_component_for(parent_theme)
    base_name = "#{parent_theme.name}#{CUSTOMIZATIONS_SUFFIX}"

    candidate = Theme.where(name: base_name).first
    if candidate&.component? && candidate.remote_theme_id.nil?
      ensure_child_link(parent_theme, candidate)
      return candidate, false
    end

    if candidate.nil?
      created = Theme.create!(name: base_name, component: true, user_id: parent_theme.user_id)
      ensure_child_link(parent_theme, created)
      return created, true
    end

    # Name collision with an unusable theme — pick a free suffix.
    suffix = 2
    suffix += 1 while Theme.where(name: "#{base_name}-#{suffix}").exists?
    created =
      Theme.create!(name: "#{base_name}-#{suffix}", component: true, user_id: parent_theme.user_id)
    ensure_child_link(parent_theme, created)
    [created, true]
  end

  def ensure_child_link(parent_theme, child_theme)
    return if parent_theme.child_theme_ids.include?(child_theme.id)
    parent_theme.add_relative_theme!(:child, child_theme)
  end

  def upsert_field(target_theme:, params:)
    field =
      target_theme.set_field(
        target: :common,
        name: params.outlet_name,
        type: :block_layout,
        value: params.layout_json,
      )
    context[:field] = field
  end

  def save_target_theme(target_theme:)
    target_theme.save!
  end

  # `set_field` builds (or updates) an in-memory ThemeField; baking happens
  # on save via `ensure_baked!`. Reload so we observe the persisted state.
  def reload_field(field:)
    context[:field] = field.reload if field
  end

  # Even on a successful save, the bake step may have flagged a structural
  # error and stored it on the field. Surface that as a service failure
  # (rather than a silent half-baked field) so the controller returns a
  # 422 to the client.
  def guard_against_bake_error(field:)
    fail!(field.error) if field&.error.present?
  end

  # Notifies other tabs / sessions that this outlet's layout has changed.
  # Consumers subscribe to `/block-layouts/<theme_id>` and re-publish
  # the payload via `api.setLayoutLayer(outlet, "theme", layout, {themeId})`,
  # so rendered outlets refresh without a page reload.
  #
  # Published per-target-theme so subscribers only handle messages from
  # themes that are part of their active stack — there's no point telling
  # a client about edits to a theme they're not rendering.
  def publish_message_bus_update(target_theme:, params:, field:)
    return if field.nil? || field.value_baked.blank?
    parsed =
      begin
        JSON.parse(field.value_baked)
      rescue JSON::ParserError
        nil
      end
    return if parsed.nil?

    MessageBus.publish(
      "/block-layouts/#{target_theme.id}",
      {
        outlet: params.outlet_name,
        layout: parsed["layout"],
        schema_version: parsed["schema_version"],
        theme_id: target_theme.id,
      },
    )
  end
end
