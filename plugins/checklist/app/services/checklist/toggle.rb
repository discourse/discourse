# frozen_string_literal: true

module Checklist
  class Toggle
    include Service::Base

    params do
      attribute :post_id, :integer
      attribute :checkbox_offset, :integer

      validates :post_id, presence: true
      validates :checkbox_offset, numericality: { greater_than_or_equal_to: 0 }
    end

    policy :checklist_enabled
    model :post
    policy :can_edit_post

    step :validate_checkbox_at_offset
    step :toggle_checkbox
    step :revise_post
    step :publish_change

    private

    def fetch_post(params:)
      Post.find_by(id: params.post_id)
    end

    def can_edit_post(guardian:, post:)
      guardian.can_edit?(post)
    end

    def checklist_enabled
      SiteSetting.checklist_enabled
    end

    def validate_checkbox_at_offset(post:, params:)
      raw = post.raw
      offset = params.checkbox_offset

      # Validate the offset points to a valid checkbox
      return fail!(I18n.t("checklist.invalid_checkbox_offset", offset:)) if offset >= raw.length

      # Skip if preceded by ! (image alt text like ![](url))
      if offset > 0 && raw[offset - 1] == "!"
        return fail!(I18n.t("checklist.invalid_checkbox_offset", offset:))
      end

      # Skip if preceded by \ (escaped bracket)
      if offset > 0 && raw[offset - 1] == "\\"
        return fail!(I18n.t("checklist.invalid_checkbox_offset", offset:))
      end

      # Extract 3 characters at offset to check if it's a checkbox
      segment = raw[offset, 3]

      # Must match [ ], [x], or [X]
      unless segment&.match?(/\[[ xX]\]/)
        return fail!(I18n.t("checklist.invalid_checkbox_offset", offset:))
      end

      checkbox = segment[0, 3]

      # [X] is a permanent checkbox that cannot be toggled
      return fail!(I18n.t("checklist.permanent_checkbox")) if checkbox == "[X]"

      context[:checkbox_match] = checkbox
      context[:currently_checked] = checkbox == "[x]"
    end

    def toggle_checkbox(post:, params:, checkbox_match:, currently_checked:)
      offset = params.checkbox_offset
      new_value = currently_checked ? "[ ]" : "[x]"
      new_raw = post.raw[0...offset] + new_value + post.raw[(offset + checkbox_match.length)..]

      context[:new_raw] = new_raw
      context[:new_checked] = !currently_checked
    end

    def revise_post(post:, new_raw:, guardian:)
      PostRevisor.new(post).revise!(
        guardian.user,
        { raw: new_raw },
        bypass_bump: true,
        skip_validations: true,
        force_new_version: true,
        skip_publish: true,
      )
    end

    def publish_change(post:, params:, new_checked:)
      post.publish_message!(
        "/checklist/#{post.topic_id}",
        post_id: post.id,
        checkbox_offset: params.checkbox_offset,
        checked: new_checked,
      )
    end
  end
end
