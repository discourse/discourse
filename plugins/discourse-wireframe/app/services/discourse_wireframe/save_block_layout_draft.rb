# frozen_string_literal: true

module DiscourseWireframe
  # Saves a per-user, never-live draft of a single outlet's block layout. Drafts
  # are private to the editing user and are NOT baked — an invalid mid-edit
  # layout is allowed. Publishing (`Themes::SaveBlockLayout`) promotes a draft to
  # the live field.
  class SaveBlockLayoutDraft
    include Service::Base

    params do
      attribute :theme_id, :integer
      attribute :outlet_name, :string
      attribute :layout_json, :string
      attribute :base_version_token, :string

      # Allow negative ids: core "system" themes (Foundation, Horizon) have
      # negative ids and are legitimate draft targets. `0` is never a real theme.
      validates :theme_id, presence: true, numericality: { only_integer: true, other_than: 0 }
      validates :outlet_name, presence: true, format: { with: /\A[a-z0-9_:\-]+\z/ }
      validates :layout_json,
                presence: true,
                length: {
                  maximum: DiscourseWireframe::BlockLayoutDraft::MAX_DATA_BYTES,
                }
    end

    policy :current_user_is_admin
    step :upsert_draft

    private

    def current_user_is_admin(guardian:)
      guardian.is_admin?
    end

    def upsert_draft(params:, guardian:)
      draft =
        DiscourseWireframe::BlockLayoutDraft.find_or_initialize_by(
          user_id: guardian.user&.id,
          theme_id: params.theme_id,
          outlet: params.outlet_name,
        )
      draft.update!(data: params.layout_json, base_version_token: params.base_version_token)
      context[:draft] = draft
    end
  end
end
