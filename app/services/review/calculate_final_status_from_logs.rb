# frozen_string_literal: true

module Review
  # Calculates the final reviewable status based on action logs from multiple bundles.
  #
  # @example
  #   Review::CalculateFinalStatusFromLogs.call(
  #     reviewable_id: my_reviewable.id,
  #     guardian: guardian,
  #     args: {}
  #   )
  #
  class CalculateFinalStatusFromLogs
    include Service::Base

    # @!method self.call(reviewable_id:, guardian:, args:)
    #   @param reviewable_id [Integer] The ID of the reviewable to calculate status for
    #   @param guardian [Guardian] The guardian to check permissions for
    #   @param args [Hash] Additional arguments for building actions
    #   @return [Service::Base::Context]

    params do
      attribute :reviewable_id, :integer
      attribute :guardian
      attribute :args, default: -> { {} }

      validates :reviewable_id, presence: true
      validates :guardian, presence: true
    end

    model :reviewable
    model :reviewable_action_logs
    policy :all_bundles_actioned

    step :calculate_status

    private

    def fetch_reviewable(params:)
      Reviewable.find_by(id: params.reviewable_id)
    end

    def fetch_reviewable_action_logs(reviewable:)
      reviewable
        .reviewable_action_logs
        .reorder(bundle: :asc, created_at: :desc)
        .select(
          "DISTINCT ON (reviewable_action_logs.bundle) reviewable_action_logs.bundle, reviewable_action_logs.status",
        )
    end

    def all_bundles_actioned(reviewable:, reviewable_action_logs:, params:)
      actions = reviewable.actions_for(params.guardian, params.args)

      current_bundle_types = actions.bundles.map { |b| b.id.split("-", 2).last }
      logged_bundle_types = reviewable_action_logs.uniq.pluck(:bundle)

      current_bundle_types.all? { |type| logged_bundle_types.include?(type) }
    end

    def calculate_status(reviewable:, reviewable_action_logs:)
      statuses = reviewable_action_logs.uniq.pluck(:status).map(&:to_sym)

      return context[:status] = :pending if statuses.empty?

      return context[:status] = :deleted if statuses.include?(:deleted)
      return context[:status] = :approved if statuses.include?(:approved)
      return context[:status] = :rejected if statuses.include?(:rejected)
      return context[:status] = :ignored if statuses.include?(:ignored)

      context[:status] = :pending
    end
  end
end
