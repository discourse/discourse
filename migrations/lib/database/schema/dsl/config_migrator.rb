# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  class ConfigMigrator
    def initialize(yaml_path, output_path)
      @yaml_path = yaml_path
      @output_path = output_path
      @config = YAML.load_file(@yaml_path, symbolize_names: true)
    end

    def migrate!
      FileUtils.mkdir_p(@output_path)
      FileUtils.mkdir_p(File.join(@output_path, "enums"))
      FileUtils.mkdir_p(File.join(@output_path, "tables"))

      generate_config_rb
      generate_conventions_rb
      generate_ignored_rb
      generate_enums
      generate_tables
    end

    private

    def generate_config_rb
      output = @config[:output]

      content = <<~RUBY
        # frozen_string_literal: true

        Migrations::Database::Schema.configure do
          output do
            schema_file "#{output[:schema_file]}"
            models_directory "#{output[:models_directory]}"
            models_namespace "#{output[:models_namespace]}"
            enums_directory "#{output[:enums_directory]}"
            enums_namespace "#{output[:enums_namespace]}"
          end
        end
      RUBY

      write_file("config.rb", content)
    end

    def generate_conventions_rb
      global = @config.dig(:schema, :global) || {}
      columns = global[:columns] || {}

      lines = []
      lines << "# frozen_string_literal: true"
      lines << ""
      lines << "Migrations::Database::Schema.conventions do"

      if (modified = columns[:modify])
        modified.each do |mod|
          if mod[:name]
            lines << "  column :#{mod[:name]} do"
            lines << "    rename_to :#{mod[:rename_to]}" if mod[:rename_to]
            lines << "    type :#{mod[:datatype]}" if mod[:datatype]
            if mod.key?(:nullable)
              mod[:nullable] ? lines << "    required false" : lines << "    required"
            end
            lines << "  end"
            lines << ""
          elsif mod[:name_regex]
            lines << "  columns_matching(/#{mod[:name_regex]}/) { type :#{mod[:datatype]} }"
          end
        end
      end

      if (excluded = columns[:exclude])
        lines << ""
        lines << "  ignore_columns #{excluded.map { |c| ":#{c}" }.join(", ")}"
      end

      lines << "end"

      write_file("conventions.rb", lines.join("\n") + "\n")
    end

    def generate_ignored_rb
      global_tables = @config.dig(:schema, :global, :tables, :exclude) || []
      return if global_tables.empty?

      lines = []
      lines << "# frozen_string_literal: true"
      lines << ""
      lines << "Migrations::Database::Schema.ignored do"

      grouped = group_tables_by_prefix(global_tables)

      grouped.each do |prefix, tables|
        if tables.size == 1
          lines << "  table :#{tables.first}, \"TODO: add reason\""
        else
          table_syms = tables.map { |t| ":#{t}" }.join(", ")
          lines << "  tables #{table_syms},"
          lines << "         reason: \"TODO: add reason for #{prefix}* tables\""
        end
        lines << ""
      end

      lines << "end"

      write_file("ignored.rb", lines.join("\n") + "\n")
    end

    def generate_enums
      enums = @config.dig(:schema, :enums) || {}

      enums.each do |name, config|
        content = generate_enum_file(name, config)
        write_file("enums/#{name}.rb", content)
      end
    end

    def generate_enum_file(name, config)
      lines = []
      lines << "# frozen_string_literal: true"
      lines << ""
      lines << "Migrations::Database::Schema.enum :#{name} do"

      if config[:source]
        lines << "  source \"#{config[:source]}\""
      elsif config[:values]
        if config[:values].is_a?(Array)
          config[:values].each_with_index { |val, idx| lines << "  value :#{val}, #{idx}" }
        else
          config[:values].each { |val, num| lines << "  value :#{val}, #{num}" }
        end
      end

      lines << "end"
      lines.join("\n") + "\n"
    end

    def generate_tables
      tables = @config.dig(:schema, :tables) || {}

      tables.each do |name, config|
        content = generate_table_file(name, config || {})
        write_file("tables/#{name}.rb", content)
      end
    end

    def generate_table_file(name, config)
      lines = []
      lines << "# frozen_string_literal: true"
      lines << ""
      lines << "Migrations::Database::Schema.table :#{name} do"

      if config[:copy_of]
        lines << "  copy_structure_from :#{config[:copy_of]}"
        lines << ""
      end

      if config[:primary_key_column_names]&.size.to_i > 1
        pks = config[:primary_key_column_names].map { |pk| ":#{pk}" }.join(", ")
        lines << "  primary_key #{pks}"
        lines << ""
      end

      columns_config = config[:columns] || {}

      if (included = columns_config[:include])
        lines << "  include #{included.map { |c| ":#{c}" }.join(", ")}"
        lines << ""
      end

      if (added = columns_config[:add])
        added.each do |col|
          type = col[:enum] || col[:datatype]
          opts = []
          opts << "required: true" if col[:nullable] == false
          opts << "enum: :#{col[:enum]}" if col[:enum]
          opts_str = opts.any? ? ", #{opts.join(", ")}" : ""
          lines << "  add_column :#{col[:name]}, :#{type}#{opts_str}"
        end
        lines << ""
      end

      if (modified = columns_config[:modify])
        modified.each do |col|
          opts = []
          opts << ":#{col[:datatype]}" if col[:datatype]
          opts << "required: true" if col[:nullable] == false
          lines << "  column :#{col[:name]}, #{opts.join(", ")}" if opts.any?
        end
        lines << "" if modified.any?
      end

      if (excluded = columns_config[:exclude])
        excluded.each { |col| lines << "  ignore :#{col}, \"TODO: add reason\"" }
        lines << ""
      end

      if config[:indexes]
        config[:indexes].each do |idx|
          cols = idx[:columns].map { |c| ":#{c}" }.join(", ")
          opts = []
          opts << "name: :#{idx[:name]}" if idx[:name]
          opts << "where: \"#{idx[:condition]}\"" if idx[:condition]

          method = idx[:unique] ? "unique_index" : "index"
          lines << "  #{method} #{cols}, #{opts.join(", ")}"
        end
        lines << ""
      end

      if config[:constraints]
        config[:constraints].each do |constraint|
          lines << "  check :#{constraint[:name]}, \"#{constraint[:condition]}\""
        end
        lines << ""
      end

      lines << "end"
      lines.join("\n") + "\n"
    end

    def group_tables_by_prefix(tables)
      groups = {}

      tables.sort.each do |table|
        prefix = extract_prefix(table)
        groups[prefix] ||= []
        groups[prefix] << table
      end

      groups.sort_by { |prefix, grouped| [-grouped.size, prefix] }.to_h
    end

    def extract_prefix(table_name)
      prefixes = %w[
        chat_
        ai_
        discourse_
        user_
        post_
        topic_
        category_
        tag_
        group_
        badge_
        theme_
        web_hook
        sidebar_
        poll_
        directory_
      ]

      prefixes.find { |p| table_name.start_with?(p) } || "#{table_name.split("_").first}_"
    end

    def write_file(relative_path, content)
      path = File.join(@output_path, relative_path)
      File.write(path, content)
    end
  end
end
