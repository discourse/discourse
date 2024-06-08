# frozen_string_literal: true

module Migrations
  module Converters
    def self.converter_paths
      base_path = File.join(Migrations.root_path, "lib", "converters", "base")
      core_paths = Dir[File.join(Migrations.root_path, "lib", "converters", "*")]
      private_paths = Dir[File.join(Migrations.root_path, "private", "converters", "*")]

      core_paths - [base_path] + private_paths
    end

    def self.converter_names
      names = converter_paths.map! { |path| File.basename(path) }
      names.reject! { |name| name == "base" }
      names.sort!

      duplicates = names.select { |name| names.count(name) > 1 }.uniq

      if duplicates.any?
        raise StandardError.new("Duplicate converter names detected: #{duplicates.join(", ")}")
      end

      names
    end
  end
end
