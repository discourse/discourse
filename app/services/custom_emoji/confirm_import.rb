# frozen_string_literal: true

class CustomEmoji::ConfirmImport
  include Service::Base

  params do
    attribute :token, :string
    attribute :resolutions, default: -> { {} }

    validates :token, presence: true
  end

  model :rows, :fetch_preview
  try(ActiveRecord::RecordInvalid) { transaction { step :apply_rows } }

  step :clear_preview
  step :refresh_emoji_cache

  private

  def fetch_preview(params:, guardian:)
    CustomEmoji::ImportPreviewCache.new(guardian.user).fetch(params.token)
  end

  def apply_rows(rows:, params:, guardian:)
    context[:report] = CustomEmoji::Action::ApplyImportRows.call(
      rows:,
      resolutions: params.resolutions,
      acting_user: guardian.user,
    )
  end

  def clear_preview(params:, guardian:)
    CustomEmoji::ImportPreviewCache.new(guardian.user).delete(params.token)
  end

  def refresh_emoji_cache
    Emoji.clear_cache
  end
end
