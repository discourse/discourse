# frozen_string_literal: true

# Publishes a `block_layout` ThemeField for a single outlet on a theme — the
# live, broadcast write. Concurrent publishers to the same `(theme, outlet)` are
# serialized by a `DistributedMutex` so the second one reads the first's
# committed state; an `expected_version_token` that no longer matches the live
# field fails the publish (the controller maps it to HTTP 409), preventing a
# silent multi-admin clobber.
#
# Git-imported themes (`remote_theme_id` set) cannot be published — a policy
# fails the service. Their layouts reach the repo via export / duplicate-to-an-
# editable-theme flows instead, so a Git theme's live field is never written.
#
# @example
#   Themes::SaveBlockLayout.call(
#     guardian: guardian,
#     params: {
#       theme_id: theme.id,
#       outlet_name: "homepage-blocks",
#       layout_json: layout.to_json,
#       expected_version_token: token,
#     }
#   )
#
class Themes::SaveBlockLayout
  include Service::Base

  # @!method self.call(guardian:, params:)
  #   @param [Guardian] guardian
  #   @param [Hash] params
  #   @option params [Integer] :theme_id The id of the theme being edited.
  #   @option params [String] :outlet_name The block outlet identifier
  #     (e.g. `"homepage-blocks"`). Stored as the ThemeField's `name`.
  #   @option params [String] :layout_json The serialized layout payload
  #     ({ schema_version, layout: [...] }). Validated structurally during baking.
  #   @option params [String] :expected_version_token The version token the
  #     caller last observed for this outlet's live field. When present and it no
  #     longer matches the current live token, the publish fails as stale (409).
  #     Omit (nil) to opt out of the check.
  #   @return [Service::Base::Context]

  params do
    attribute :theme_id, :integer
    attribute :outlet_name, :string
    attribute :layout_json, :string
    attribute :expected_version_token, :string

    validates :theme_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :outlet_name, presence: true, format: { with: /\A[a-z0-9_:\-]+\z/ }
    validates :layout_json, presence: true, length: { maximum: 1024**2 }
  end

  model :theme
  policy :current_user_is_admin
  policy :theme_is_not_git

  lock(:theme_id, :outlet_name) do
    transaction do
      step :guard_stale_publish
      step :upsert_field
      step :save_theme
      step :reload_field
      step :guard_against_bake_error
    end
  end

  step :publish_message_bus_update

  private

  def fetch_theme(params:)
    Theme.find_by(id: params.theme_id)
  end

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  # A Git-imported theme's live field is never written here; its layouts are made
  # real through export / duplicate / a local override component instead. "Git"
  # means an actual remote URL (matching `RemoteTheme#is_git?`), NOT merely a
  # `remote_theme` record — a locally zip/dir-imported theme (e.g. an editable
  # duplicate or customization component) carries a blank-`remote_url`
  # `remote_theme` and IS writable.
  def theme_is_not_git(theme:)
    theme.remote_theme&.is_git? != true
  end

  # Runs first, inside the lock + transaction: reads the live baked value (under
  # the row lock the mutex provides) and fails if it no longer matches the token
  # the caller last observed. A nil `expected_version_token` opts out; an empty
  # string matches an absent field (the first publish).
  def guard_stale_publish(theme:, params:)
    return if params.expected_version_token.nil?

    current_value_baked, current_updated_at =
      theme
        .theme_fields
        .where(
          name: params.outlet_name,
          target_id: Theme.targets[:common],
          type_id: ThemeField.types[:block_layout],
        )
        .pick(:value_baked, :updated_at)

    current_token = Themes::BlockLayoutVersion.token_for(current_value_baked)
    return if params.expected_version_token == current_token

    # Hand the controller the live token and publish time so a stale caller can
    # surface what changed and re-publish against the current version.
    context[:current_version] = current_token
    context[:published_at] = current_updated_at
    fail!("stale_block_layout")
  end

  def upsert_field(theme:, params:)
    field =
      theme.set_field(
        target: :common,
        name: params.outlet_name,
        type: :block_layout,
        value: params.layout_json,
      )
    context[:field] = field
  end

  def save_theme(theme:)
    theme.save!
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
  # Consumers subscribe to `/block-layouts/<theme_id>` and re-publish the
  # payload via `api.setLayoutLayer(outlet, "theme", layout, { themeId })`, so
  # rendered outlets refresh without a page reload. The `version_token` lets a
  # tab that observes another admin's publish refresh its captured token.
  def publish_message_bus_update(theme:, params:, field:)
    return if field.nil? || field.value_baked.blank?
    parsed =
      begin
        JSON.parse(field.value_baked)
      rescue JSON::ParserError
        nil
      end
    return if parsed.nil?

    MessageBus.publish(
      "/block-layouts/#{theme.id}",
      {
        outlet: params.outlet_name,
        layout: parsed["layout"],
        schema_version: parsed["schema_version"],
        theme_id: theme.id,
        version_token: Themes::BlockLayoutVersion.token_for(field.value_baked),
      },
    )
  end
end
