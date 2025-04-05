# frozen_string_literal: true

module Migrations::Importer
  class SharedData
    def initialize(discourse_db)
      @discourse_db = discourse_db
    end

    def load_set(sql)
      @discourse_db.query_array(sql).map(&:first).to_set
    end

    def load_mapping(sql)
      rows = @discourse_db.query_array(sql)

      if rows.first && rows.first.size > 2
        rows.to_h { |key, *values| [key, *values] }
      else
        rows.to_h
      end
    end

    def load(type)
      case type
      when :usernames
        @existing_usernames_lower ||= load_set <<~SQL
          SELECT username_lower
          FROM users
        SQL
      when :group_names
        @existing_group_names_lower ||= load_set <<~SQL
          SELECT LOWER(name)
          FROM groups
        SQL
      else
        raise "Unknown type: #{type}"
      end
    end

    def unload_shared_data(type)
      case type
      when :usernames
        @existing_usernames_lower = nil
      when :group_names
        @existing_group_names_lower = nil
      else
        raise "Unknown type: #{type}"
      end
    end
  end
end
