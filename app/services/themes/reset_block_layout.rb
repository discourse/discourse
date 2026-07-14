# frozen_string_literal: true

# Resets an outlet to its default: deletes the live `block_layout` field, then
# broadcasts the removal so rendered outlets fall back to the underlying (theme
# / code) layer without a page reload. (Any per-user draft is cleaned up by the
# editor client, not here — drafts are a plugin concern.)
class Themes::ResetBlockLayout
  include Service::Base

  params do
    attribute :theme_id, :integer
    attribute :outlet_name, :string

    validates :theme_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :outlet_name, presence: true, format: { with: /\A[a-z0-9_:\-]+\z/ }
  end

  model :theme
  policy :current_user_is_admin
  policy :theme_is_not_git
  transaction { step :delete_live_field }

  step :broadcast_removal

  private

  def fetch_theme(params:)
    Theme.find_by(id: params.theme_id)
  end

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  # A Git-imported theme's live field is never written or cleared here, matching
  # the publish path. "Git" means an actual remote URL (`RemoteTheme#is_git?`),
  # not merely a `remote_theme` record — a locally-imported editable theme is
  # writable.
  def theme_is_not_git(theme:)
    theme.remote_theme&.is_git? != true
  end

  # `set_field` with a blank value marks the field for destruction; `save!`
  # removes the row and rebakes.
  def delete_live_field(theme:, params:)
    theme.set_field(target: :common, name: params.outlet_name, type: :block_layout, value: nil)
    theme.save!
  end

  def broadcast_removal(theme:, params:)
    MessageBus.publish(
      "/block-layouts/#{theme.id}",
      { outlet: params.outlet_name, layout: nil, theme_id: theme.id, version_token: "" },
    )
  end
end
