# frozen_string_literal: true

module DiscourseDataExplorer
  class UpdateQuery
    include Service::Base

    options { attribute :restore_hidden, :boolean, default: false }

    policy :can_update_query
    model :query

    params(
      default_values_from: :query,
      from_resource: QueryResource,
      only: %i[name description sql tags group_ids],
    ) do
      attribute :tags, :array, element_type: ActiveModel::Type.lookup(:string)

      before_validation :restore_default_query_definition, if: -> { model&.default? }

      validates :name, presence: true
      validate { errors.add(:sql, :blank) if provided?(:sql) && sql.nil? }
      validate { errors.add(:tags, :invalid) if provided?(:tags) && tags.nil? }

      def query_attributes = slice(:name, :description, :sql)

      def requested_group_ids = Array.wrap(group_ids).uniq

      private

      def restore_default_query_definition
        assign_attributes(model.slice(:name, :description, :sql))
      end
    end

    only_if(:groups_provided?) do
      model :groups, optional: true
      policy :requested_groups_exist
    end

    try ActiveRecord::RecordInvalid do
      transaction do
        step :update_query
        only_if(:groups_provided?) { step :replace_groups }
        only_if(:tags_provided?) { step :sync_tags }
      end
    end

    only_if(:sql_changed?) { step :invalidate_cached_results }

    private

    def can_update_query(guardian:)
      guardian.is_admin?
    end

    def fetch_query(params:, options:)
      scope = options.restore_hidden ? Query.all : Query.visible
      scope.find_by(id: params.id)
    end

    def groups_provided?(params:)
      params.groups_provided?
    end

    def fetch_groups(params:)
      Group.where(id: params.requested_group_ids).to_a
    end

    def requested_groups_exist(params:, groups:)
      groups.size == params.requested_group_ids.size
    end

    def update_query(query:, params:, options:)
      attributes = params.query_attributes
      attributes[:hidden] = false if options.restore_hidden
      query.update!(attributes)
    end

    def replace_groups(query:, groups:)
      query.groups = groups
    end

    def tags_provided?(params:)
      params.provided?(:tags)
    end

    def sync_tags(query:, params:)
      QueryTag.sync!(query:, names: params.tags)
    end

    def sql_changed?(query:)
      query.saved_change_to_sql?
    end

    def invalidate_cached_results(query:)
      ActiveRecord.after_all_transactions_commit { QueryRunner.invalidate(query.id) }
    end
  end
end
