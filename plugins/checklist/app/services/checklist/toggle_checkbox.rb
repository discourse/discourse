# frozen_string_literal: true

module Checklist
  class ToggleCheckbox
    include Service::Base

    MAX_BATCH_SIZE = 50
    INTEGER_TYPE = ActiveModel::Type::Integer.new
    BOOLEAN_TYPE = ActiveModel::Type::Boolean.new
    ResolvedToggle = Data.define(:request, :location, :checkbox)

    params do
      attribute :post_id, :integer
      attribute :toggles, :array
      attribute :expected_updated_at, :string
      attribute :mutation_id, :string

      before_validation do
        self.toggles =
          toggles.map do |toggle|
            values = toggle.respond_to?(:to_h) ? toggle.to_h.symbolize_keys : {}
            {
              checkbox_index: INTEGER_TYPE.cast(values[:checkbox_index]),
              checkbox_count: INTEGER_TYPE.cast(values[:checkbox_count]),
              checkbox_source: values[:checkbox_source].presence,
              checked: BOOLEAN_TYPE.cast(values[:checked]),
            }
          end if toggles.is_a?(Array)
      end

      validates :post_id, presence: true
      validates :toggles, presence: true, length: { maximum: MAX_BATCH_SIZE }
      validates :expected_updated_at, presence: true
      validates :mutation_id, presence: true, length: { maximum: 100 }
      validate :toggles_are_valid, if: -> { toggles.present? }
      validate :toggle_targets_are_unique, if: -> { toggles.present? }

      private

      def toggles_are_valid
        toggles.each do |toggle|
          valid_index = toggle[:checkbox_index].is_a?(Integer) && toggle[:checkbox_index] >= 0
          valid_count = toggle[:checkbox_count].is_a?(Integer) && toggle[:checkbox_count] > 0
          valid_source =
            toggle[:checkbox_source].to_s.match?(/\A\d+:\d+\z/) &&
              toggle[:checkbox_source].length <= 30
          valid_checked = [true, false].include?(toggle[:checked])

          if !valid_index || (!valid_source && !valid_count) || !valid_checked
            errors.add(:toggles, :invalid)
          end
        end
      end

      def toggle_targets_are_unique
        targets =
          toggles.map do |toggle|
            toggle[:checkbox_source].presence || "index:#{toggle[:checkbox_index]}"
          end
        errors.add(:toggles, :taken) if targets.uniq.size != targets.size
      end
    end

    policy :checklist_enabled
    model :post
    policy :can_edit_post
    policy :post_unchanged
    model :resolved_toggles, :resolve_toggles
    policy :checkbox_counts_unchanged
    policy :checkboxes_found
    policy :checkboxes_toggleable

    only_if :checkbox_states_differ do
      step :revise_post
    end

    def self.retryable_conflict?(post:, expected_updated_at:)
      expected_at = Time.iso8601(expected_updated_at)
      first_raw_revision =
        post
          .revisions
          .where("post_revisions.updated_at > ?", expected_at)
          .order(:updated_at)
          .find { |revision| revision.modifications["raw"].present? }
      return false if first_raw_revision.nil?

      previous_raw = first_raw_revision.modifications["raw"].first
      normalize_checkbox_states(previous_raw) == normalize_checkbox_states(post.reload.raw)
    rescue ArgumentError
      false
    end

    def self.normalize_checkbox_states(raw)
      raw.gsub(/\[(?: |x)?\]/, "[ ]")
    end
    private_class_method :normalize_checkbox_states

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

    def post_unchanged(post:, params:)
      expected = Time.iso8601(params.expected_updated_at)
      (expected.to_r * 1000).floor == (post.updated_at.to_time.to_r * 1000).floor
    rescue ArgumentError
      false
    end

    def resolve_toggles(post:, params:)
      targets =
        params.toggles.map do |toggle|
          CheckboxLocator::Target.new(
            index: toggle[:checkbox_index],
            source: toggle[:checkbox_source].presence,
          )
        end
      locations = CheckboxLocator.call_many(post:, targets:)

      params
        .toggles
        .zip(locations)
        .map do |request, location|
          ResolvedToggle.new(request:, location:, checkbox: location.checkbox)
        end
    end

    def checkbox_counts_unchanged(resolved_toggles:)
      resolved_toggles.all? do |toggle|
        toggle.request[:checkbox_source].present? ||
          toggle.location.count == toggle.request[:checkbox_count]
      end
    end

    def checkboxes_found(resolved_toggles:)
      resolved_toggles.all? { |toggle| toggle.checkbox.present? }
    end

    def checkboxes_toggleable(resolved_toggles:)
      resolved_toggles.all? { |toggle| toggle.checkbox.toggleable? }
    end

    def checkbox_states_differ(resolved_toggles:)
      resolved_toggles.any? { |toggle| toggle.checkbox.checked? != toggle.request[:checked] }
    end

    def revise_post(post:, resolved_toggles:, params:, guardian:)
      expected_raw = post.raw
      changed_toggles =
        resolved_toggles.select { |toggle| toggle.checkbox.checked? != toggle.request[:checked] }
      new_raw = expected_raw
      changed_toggles
        .sort_by { |toggle| -toggle.checkbox.offset }
        .each do |toggle|
          new_raw = toggle.checkbox.replace_in(new_raw, checked: toggle.request[:checked])
        end

      revised =
        PostRevisor.new(post).revise!(
          guardian.user,
          { raw: new_raw },
          bypass_bump: true,
          expected_raw:,
          preserve_cooked_token: params.mutation_id,
        )

      if !revised
        if post.errors.details[:base].any? { |error| error[:error] == :edit_conflict }
          fail!(:edit_conflict)
        else
          fail!(:revision_failed)
        end
      end
    end
  end
end
