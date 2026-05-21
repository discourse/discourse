# frozen_string_literal: true

module DiscourseDataExplorer
  class AdminDashboardReportProvider < ::AdminDashboard::Reports::SourceProvider
    SOURCE_NAME = "data_explorer_query"

    def self.source_name
      SOURCE_NAME
    end

    def self.label
      I18n.t("data_explorer.admin_dashboard_label")
    end

    def self.resolve_many(identifiers, guardian:)
      return {} if guardian.nil?

      load_queries(identifiers).each_with_object({}) do |query, hash|
        next if !guardian.user_can_access_query?(query)
        hash[query.id.to_s] = build_resolved(query)
      end
    end

    def self.list_all(search: nil, offset: 0, limit: nil)
      persisted_total = persisted_scope(search: search).count
      unpersisted = Query.unpersisted_defaults(search: search).sort_by { |q| q.name.to_s.downcase }

      results = []
      remaining = limit

      if offset < persisted_total
        take =
          if remaining
            [remaining, persisted_total - offset].min
          else
            persisted_total - offset
          end
        results.concat(persisted_scope(search: search).offset(offset).limit(take).to_a)
        remaining -= results.size if remaining
      end

      if remaining.nil? || remaining > 0
        unpersisted_offset = [offset - persisted_total, 0].max
        slice =
          if remaining
            unpersisted[unpersisted_offset, remaining]
          else
            unpersisted[unpersisted_offset..]
          end
        results.concat(Array(slice))
      end

      results.map { |q| build_resolved(q) }
    end

    def self.fetch_many(identifiers, guardian:, filters: {})
      return {} if guardian&.user.nil?

      params = filters.with_indifferent_access

      load_queries(identifiers).each_with_object({}) do |query, hash|
        next if !guardian.user_can_access_query?(query)
        result = QueryRunner.run(query, params, current_user: guardian.user)
        result = result.merge(empty: Array(result[:rows]).empty?) if result.is_a?(Hash)
        hash[query.id.to_s] = result
      end
    end

    def self.build_resolved(query)
      ::AdminDashboard::Reports::ResolvedReport.new(
        source: SOURCE_NAME,
        identifier: query.id.to_s,
        title: query.name,
        description: query.description,
        label: label,
        url: "/admin/plugins/discourse-data-explorer/queries/#{query.id}",
      )
    end
    private_class_method :build_resolved

    def self.load_queries(identifiers)
      ids = identifiers.map(&:to_i).reject(&:zero?)
      return [] if ids.empty?

      positive_ids, negative_ids = ids.partition(&:positive?)
      queries = []

      if positive_ids.any?
        queries.concat(Query.where(id: positive_ids, hidden: false).includes(:groups))
      end

      if negative_ids.any?
        valid_default_ids = negative_ids.select { |id| Queries.default.key?(id.to_s) }
        persisted_by_id = Query.where(id: valid_default_ids).index_by(&:id)
        valid_default_ids.each do |id|
          query = persisted_by_id[id] || Query.new
          query.attributes = Queries.default[id.to_s]
          query.user_id = Discourse::SYSTEM_USER_ID.to_s
          queries << query if !query.hidden
        end
      end

      queries
    end
    private_class_method :load_queries

    def self.persisted_scope(search:)
      scope = Query.where(hidden: false).includes(:groups).order(:name)
      scope = scope.where(<<~SQL, s: "%#{Query.sanitize_sql_like(search)}%") if search.present?
        name ILIKE :s OR description ILIKE :s
      SQL
      scope
    end
    private_class_method :persisted_scope
  end
end
