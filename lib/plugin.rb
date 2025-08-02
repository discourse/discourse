# frozen_string_literal: true

module Plugin
  def self.initialization_guard(&block)
    begin
      block.call
    rescue => error
      plugins_directory = Rails.root + "plugins"

      if error.backtrace && error.backtrace_locations
        plugin_path =
          error
            .backtrace_locations
            .lazy
            .map do |location|
              resolved_path = location.absolute_path || location.path
              next if resolved_path.nil?
              Pathname
                .new(resolved_path)
                .ascend
                .lazy
                .find { |path| path.parent == plugins_directory }
            end
            .next

        raise unless plugin_path

        stack_trace =
          error
            .backtrace
            .each_with_index
            .inject([]) do |messages, (line, index)|
              if index == 0
                messages << "#{line}: #{error} (#{error.class})"
              else
                messages << "\t#{index}: from #{line}"
              end
            end
            .reverse
            .join("\n")

        STDERR.puts <<~TEXT
          #{stack_trace}

          ** INCOMPATIBLE PLUGIN **

          You are unable to start Discourse due to errors in the plugin at
          #{plugin_path}

          Please try removing this plugin and rebuilding again!
        TEXT
      else
        STDERR.puts <<~TEXT
          ** PLUGIN FAILURE **

          You are unable to start Discourse due to this error during plugin
          initialization:

          #{error}

          #{error.backtrace.join("\n")}
        TEXT
      end
      exit 1
    end
  end
end
