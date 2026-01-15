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

    def checklist_enabled
      SiteSetting.checklist_enabled
    end

    def fetch_post(params:)
      Post.find_by(id: params.post_id)
    end

    def can_edit_post(guardian:, post:)
      guardian.can_edit?(post)
    end

    def validate_checkbox_at_offset(post:, params:)
      segment = post.raw[params.checkbox_offset, 3]

      return fail!(I18n.t("checklist.invalid_checkbox")) if segment != "[ ]" && segment != "[x]"

      context[:currently_checked] = (segment == "[x]")
    end

    def toggle_checkbox(post:, params:, currently_checked:)
      offset = params.checkbox_offset
      new_value = currently_checked ? "[ ]" : "[x]"
      new_raw = post.raw[0...offset] + new_value + post.raw[(offset + 3)..]

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
        version: post.version,
        updated_at: post.updated_at,
      )
    end
  end
end
