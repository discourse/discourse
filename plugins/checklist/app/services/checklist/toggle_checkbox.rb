# frozen_string_literal: true

module Checklist
  class ToggleCheckbox
    include Service::Base

    params do
      attribute :post_id, :integer
      attribute :checkbox_index, :integer
      attribute :checkbox_count, :integer
      attribute :checked, :boolean

      validates :post_id, presence: true
      validates :checkbox_index, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :checkbox_count, numericality: { only_integer: true, greater_than: 0 }
      validates :checked, inclusion: { in: [true, false] }
    end

    policy :checklist_enabled

    lock(:post_id) do
      model :post
      policy :can_edit_post
      model :checkboxes, :find_checkboxes
      policy :checkboxes_unchanged
      model :checkbox, :find_checkbox
      policy :checkbox_toggleable

      only_if :checkbox_state_differs do
        step :revise_post
      end
    end

    private

    def checklist_enabled
      SiteSetting.checklist_enabled
    end

    def fetch_post(params:)
      Post.find_by(id: params.post_id)
    end

    def can_edit_post(guardian:, post:)
      guardian.can_edit?(post)
    end

    def find_checkboxes(post:)
      CheckboxLocator.call(raw: post.raw, cooked: post.cooked)
    end

    def checkboxes_unchanged(checkboxes:, params:)
      checkboxes.size == params.checkbox_count
    end

    def find_checkbox(checkboxes:, params:)
      checkboxes[params.checkbox_index]
    end

    def checkbox_toggleable(checkbox:)
      checkbox.toggleable?
    end

    def checkbox_state_differs(checkbox:, params:)
      checkbox.checked? != params.checked
    end

    def revise_post(post:, checkbox:, params:, guardian:)
      new_raw = checkbox.replace_in(post.raw, checked: params.checked)

      unless PostRevisor.new(post).revise!(guardian.user, { raw: new_raw }, bypass_bump: true)
        fail!(I18n.t("checklist.revision_failed"))
      end
    end
  end
end
