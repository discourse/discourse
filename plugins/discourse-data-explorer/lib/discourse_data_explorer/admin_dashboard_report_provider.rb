# frozen_string_literal: true

module DiscourseDataExplorer
  class AdminDashboardReportProvider < ::AdminDashboard::Reports::SourceProvider
    SOURCE_NAME = "data_explorer_query"

    def self.source_name
      SOURCE_NAME
    end

    def self.resolve_many(identifiers, guardian:)
      return {} if guardian.nil?

      load_queries(identifiers).each_with_object({}) do |query, hash|
        next if !guardian.user_can_access_query?(query)
        hash[query.id.to_s] = build_resolved(query)
      end
    end

    def self.available_for(guardian, search: nil)
      return [] if guardian.nil?

      scope = Query.where(hidden: false).includes(:groups)
      if search.present?
        sanitized = "%#{Query.sanitize_sql_like(search)}%"
        scope = scope.where("name ILIKE :s OR description ILIKE :s", s: sanitized)
      end

      scope.select { |q| guardian.user_can_access_query?(q) }.map { |q| build_resolved(q) }
    end

    def self.fetch_many(identifiers, guardian:, filters: {})
      return {} if guardian&.user.nil?

      load_queries(identifiers).each_with_object({}) do |query, hash|
        next if !guardian.user_can_access_query?(query)
        hash[query.id.to_s] = QueryRunner.run(query, filters, current_user: guardian.user)
      end
    end

    def self.build_resolved(query)
      ::AdminDashboard::Reports::ResolvedReport.new(
        source: SOURCE_NAME,
        identifier: query.id.to_s,
        title: query.name,
        description: query.description,
      )
    end

    def self.load_queries(identifiers)
      ids = identifiers.map(&:to_i).select(&:positive?)
      return Query.none if ids.empty?
      Query.where(id: ids, hidden: false).includes(:groups)
    end
  end
end
