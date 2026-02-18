# frozen_string_literal: true

module Migrations::Database::Schema
  module Helpers
    def self.escape_identifier(identifier)
      if SQLITE_KEYWORDS.include?(identifier)
        %Q("#{identifier}")
      else
        identifier
      end
    end

    def self.to_singular_classname(snake_case_string)
      snake_case_string.downcase.singularize.camelize
    end

    def self.to_const_name(name)
      name.parameterize.underscore.upcase
    end

    def self.format_ruby_files(path)
      glob_pattern = File.join(path, "*.rb")

      system(
        "bundle",
        "exec",
        "stree",
        "write",
        glob_pattern,
        exception: true,
        out: File::NULL,
        err: File::NULL,
      )
    rescue StandardError
      raise "Failed to run `bundle exec stree write '#{glob_pattern}'`"
    end
  end
end
