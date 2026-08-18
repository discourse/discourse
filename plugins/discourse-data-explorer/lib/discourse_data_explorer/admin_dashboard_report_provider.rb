# frozen_string_literal: true

module DiscourseDataExplorer
  class AdminDashboardReportProvider < ::AdminDashboard::Reports::SourceProvider
    SOURCE_NAME = "data_explorer_query"
    CACHE_MAX_AGE = 1.hour
    DASHBOARD_SUPPLIED_PARAMS = %w[start_date end_date].freeze

    def self.source_name
      SOURCE_NAME
    end

    def self.label
      I18n.t("data_explorer.admin_dashboard_label")
    end

    def self.resolve_many(identifiers, guardian:)
      return {} if guardian.nil?

      load_queries(identifiers).each_with_object({}) do |query, hash|
        next if !guardian.user_can_access_query?(query) || !mountable?(query)
        hash[query.id.to_s] = build_resolved(query)
      end
    end

    def self.list_all(search: nil, after: nil, limit: nil)
      persisted =
        persisted_after(search: search, after: after, limit: limit).map do |query|
          build_resolved(query)
        end
      unpersisted =
        seek(
          Query
            .unpersisted_defaults(search: search)
            .filter_map { |query| build_resolved(query) if mountable?(query) },
          after: after,
          limit: limit,
        )

      merged =
        (persisted + unpersisted).sort_by { |report| [report.title.to_s.downcase, report.key] }
      limit ? merged.first(limit) : merged
    end

    def self.fetch_many(identifiers, guardian:, filters: {})
      return {} if guardian&.user.nil?

      params = filters.with_indifferent_access

      load_queries(identifiers).each_with_object({}) do |query, hash|
        next if !guardian.user_can_access_query?(query) || !mountable?(query)
        result =
          QueryRunner.cached_result(query, params, max_age: CACHE_MAX_AGE) ||
            QueryRunner.run(query, params, current_user: guardian.user)
        result = result.merge(empty: Array(result[:rows]).empty?) if result.is_a?(Hash)
        hash[query.id.to_s] = result
      end
    end

    def self.prewarm(identifiers, guardian:, filters: {})
      return if guardian&.user.nil?

      params = filters.with_indifferent_access
      load_queries(identifiers).each do |query|
        query_params = params.slice(*query.params.map(&:identifier))
        next if !query.groups.empty? || !prewarmable?(query, query_params)

        QueryRunner.run(query, query_params, current_user: guardian.user)
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

    def self.mountable?(query)
      query.params.all? do |param|
        param.internal? || param.nullable || param.default.present? ||
          DASHBOARD_SUPPLIED_PARAMS.include?(param.identifier)
      end
    end
    private_class_method :mountable?

    def self.prewarmable?(query, params)
      QueryRunner.cacheable?(query) &&
        query.params.all? do |param|
          param.default.present? || param.nullable || params.key?(param.identifier)
        end
    end
    private_class_method :prewarmable?

    def self.persisted_after(search:, after:, limit:)
      if limit.nil?
        return(
          persisted_batch(search: search, after: after, limit: nil).select do |query|
            mountable?(query)
          end
        )
      end

      mountable_queries = []
      cursor = after

      loop do
        batch = persisted_batch(search: search, after: cursor, limit: limit)
        break if batch.empty?

        mountable_queries.concat(batch.select { |query| mountable?(query) })
        break if mountable_queries.size >= limit || batch.size < limit

        last = batch.last
        cursor = { title: last.name, key: "#{SOURCE_NAME}:#{last.id}" }
      end

      mountable_queries.first(limit)
    end
    private_class_method :persisted_after

    def self.persisted_batch(search:, after:, limit:)
      scope = Query.where(hidden: false)
      if search.present?
        scope =
          scope.where(
            "name ILIKE :pattern OR description ILIKE :pattern",
            pattern: "%#{Query.sanitize_sql_like(search)}%",
          )
      end
      if after
        scope =
          scope.where(
            <<~SQL,
              LOWER(name) COLLATE "C" > LOWER(:after_title)
              OR (
                LOWER(name) = LOWER(:after_title)
                AND (:prefix || id::text) COLLATE "C" > :after_key
              )
            SQL
            after_title: after[:title],
            after_key: after[:key],
            prefix: "#{SOURCE_NAME}:",
          )
      end
      scope = scope.order(Arel.sql('LOWER(name) COLLATE "C" ASC, id::text COLLATE "C" ASC'))
      scope = scope.limit(limit) if limit
      scope.to_a
    end
    private_class_method :persisted_batch
  end
end
