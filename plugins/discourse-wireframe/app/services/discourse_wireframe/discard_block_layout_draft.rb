# frozen_string_literal: true

module DiscourseWireframe
  # Deletes the caller's private block-layout draft for a single outlet.
  # Idempotent — succeeds whether or not a draft existed.
  class DiscardBlockLayoutDraft
    include Service::Base

    params do
      attribute :theme_id, :integer
      attribute :outlet_name, :string

      validates :theme_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
      validates :outlet_name, presence: true, format: { with: /\A[a-z0-9_:\-]+\z/ }
    end

    policy :current_user_is_admin
    step :delete_draft

    private

    def current_user_is_admin(guardian:)
      guardian.is_admin?
    end

    def delete_draft(params:, guardian:)
      DiscourseWireframe::BlockLayoutDraft.where(
        user_id: guardian.user&.id,
        theme_id: params.theme_id,
        outlet: params.outlet_name,
      ).delete_all
    end
  end
end
