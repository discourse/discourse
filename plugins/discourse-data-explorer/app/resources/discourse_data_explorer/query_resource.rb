# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryResource < JsonApiKit::Resource
    namespace "data-explorer"

    scope { Query.where(hidden: false).includes(:tags) }

    attribute :name
    attribute :description
    attribute :created_at
    attribute :last_run_at
    attribute(:tags) { it.tag_names }
    attribute :sql, readable: ->(guardian) { guardian.is_admin? }
    attribute(:param_info) { it.params.uniq(&:identifier).map(&:to_hash) }
    attribute(:is_default) { it.id.negative? }

    has_one :user
    has_many :groups

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
      scope.filter_by_tags(QueryTag.normalize_name(value))
    end
  end
end
