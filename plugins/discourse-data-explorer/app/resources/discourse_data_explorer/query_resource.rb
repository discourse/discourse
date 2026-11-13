# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryResource < JsonApiKit::Resource
    namespace "data-explorer"

    scope { Query.where(hidden: false).includes(:tags) }

    attribute :name, :string, writable: true
    attribute :description, :string, writable: true
    attribute :created_at
    attribute :last_run_at
    attribute(:tags, :array, writable: true) { it.tag_names }
    attribute(:automatic_tags) { Query.automatic_tag_names(it.id) }
    attribute :sql, :string, writable: true, readable: :is_admin?.to_proc
    attribute(:param_info) { it.params.uniq(&:identifier).map(&:to_hash) }
    attribute(:is_default) { it.id.negative? }

    attribute :dashboard_mountable, readable: :is_admin?.to_proc do |query|
      AdminDashboardReportProvider.mountable?(query)
    end

    attribute :dashboard_mounted, readable: :is_admin?.to_proc do |query|
      query.dashboard_report.present?
    end

    has_one :user
    has_one :cached_result

    has_many :groups, writable: true

    sort :name
    sort :last_run_at
    sort "user.username"
    default_sort last_run_at: :desc

    anchor :id
    anchor :name
    anchor :last_run_at

    page default: 50

    filter :search do |scope, value|
      pattern = "%#{Query.sanitize_sql_like(value)}%"
      table = Query.arel_table
      scope.where(table[:name].matches(pattern).or(table[:description].matches(pattern)))
    end

    filter :tag do |scope, value|
      scope.filter_by_tags(QueryTag.normalize_all(value))
    end
  end
end
