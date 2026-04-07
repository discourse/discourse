# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableQueryBuilder
    SORT_DIRECTIONS = { "asc" => "ASC", "desc" => "DESC" }.freeze
    MAX_LIMIT = 100

    def initialize(table)
      @table = table
    end

    def apply_filters(query, normalized_filter)
      return query if normalized_filter.blank? || normalized_filter["filters"].blank?

      conditions = normalized_filter["filters"].map { |f| build_arel_condition(f) }
      combined =
        if normalized_filter["type"] == "or"
          conditions.reduce(:or)
        else
          conditions.reduce(:and)
        end

      query.where(combined)
    end

    def apply_ordering(query, sort_by, sort_direction)
      return query.order(@table[:id].asc) if sort_by.blank?

      direction = SORT_DIRECTIONS[sort_direction.to_s.downcase] || "ASC"
      query.order(
        Arel.sql("#{DataTableStorage.quoted_column(sort_by)} #{direction} NULLS LAST"),
        @table[:id].asc,
      )
    end

    def apply_pagination(query, limit, offset)
      if limit.present?
        parsed_limit = [Integer(limit), MAX_LIMIT].min
        query = query.take(parsed_limit) if parsed_limit > 0
      end
      if offset.present?
        parsed_offset = Integer(offset)
        query = query.skip(parsed_offset) if parsed_offset > 0
      end
      query
    end

    private

    def build_arel_condition(filter)
      col = @table[filter["columnName"]]
      value = filter["value"]

      return filter["condition"] == "eq" ? col.eq(nil) : col.not_eq(nil) if value.nil?

      case filter["condition"]
      when "eq"
        col.eq(value)
      when "neq"
        col.not_eq(value).or(col.eq(nil))
      when "gt"
        col.gt(value)
      when "gte"
        col.gteq(value)
      when "lt"
        col.lt(value)
      when "lte"
        col.lteq(value)
      when "like"
        col.matches(escape_like_specials(value), "!", true)
      when "ilike"
        col.matches(escape_like_specials(value), "!", false)
      when "not_ilike"
        col.does_not_match(escape_like_specials(value), "!", false)
      end
    end

    def escape_like_specials(value)
      value.to_s.gsub(/[!_]/) { |match| "!#{match}" }
    end
  end
end
