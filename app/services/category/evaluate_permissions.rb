# frozen_string_literal: true

class Category::EvaluatePermissions
  include Service::Base

  params do
    attribute :group_ids, :array, default: -> { [] }

    validate :group_ids_are_integers

    def effective_group_ids
      group_ids.presence || [Group::AUTO_GROUPS[:staff]]
    end

    private

    def group_ids_are_integers
      errors.add(:group_ids, :invalid) if group_ids.any? { |group_id| !group_id.is_a?(Integer) }
    end
  end

  policy :user_will_have_access

  private

  # TODO (martin) When categories move to ACL, we will need to update this
  def user_will_have_access(guardian:, params:)
    guardian.is_admin? || guardian.user.in_any_groups?(params.effective_group_ids)
  end
end
