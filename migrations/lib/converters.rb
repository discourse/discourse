# frozen_string_literal: true

module Migrations
  module Converters
    def self.all
      @all_converters ||=
        begin
          base_path = File.join(::Migrations.root_path, "lib", "converters", "base")
          core_paths = Dir[File.join(::Migrations.root_path, "lib", "converters", "*")]
          private_paths = Dir[File.join(::Migrations.root_path, "private", "converters", "*")]
          all_paths = core_paths - [base_path] + private_paths

          all_paths.each_with_object({}) do |path, hash|
            next unless File.directory?(path)

            name = File.basename(path).downcase
            existing_path = hash[name]

            raise <<~MSG if existing_path
                Duplicate converter name found: #{name}
                  * #{existing_path}
                  * #{path}
              MSG

            hash[name] = path
          end
        end
    end

    def self.names
      self.all.keys.sort
    end

    def self.path_of(converter_name)
      converter_name = converter_name.downcase
      path = self.all[converter_name]
      raise "Could not find a converter named '#{converter_name}'" unless path
      path
    end

    def self.default_settings_path(converter_name)
      local_settings_path = File.join(path_of(converter_name), "settings.local.yml")
      return local_settings_path if File.exist?(local_settings_path)

      File.join(path_of(converter_name), "settings.yml")
    end
  end
end
