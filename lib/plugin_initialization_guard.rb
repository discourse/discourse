# frozen_string_literal: true

def plugin_initialization_guard(&block)
  begin
    block.call
  rescue => error
    plugins_directory = Rails.root + 'plugins'

    plugin_path = error.backtrace_locations.lazy.map do |location|
      Pathname.new(location.absolute_path)
        .ascend
        .lazy
        .find { |path| path.parent == plugins_directory }
    end.next

    raise unless plugin_path

    stack_trace = error.backtrace.each_with_index.inject([]) do |messages, (line, index)|
      if index == 0
        messages << "#{line}: #{error} (#{error.class})"
      else
        messages << "\t#{index}: from #{line}"
      end
    end.reverse.join("\n")

    STDERR.puts <<~MESSAGE
      #{stack_trace}

      ** INCOMPATIBLE PLUGIN **

      You are unable to build Discourse due to errors in the plugin at
      #{plugin_path}

      Please try removing this plugin and rebuilding again!
    MESSAGE
    exit 1
  end
end
