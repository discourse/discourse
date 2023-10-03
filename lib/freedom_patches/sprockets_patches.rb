# frozen_string_literal: true

# This contains two patches to make sprockets more tolerable in dev
#
# 1. Stop computing asset paths which triggers sprockets to do mountains of work
#     All our assets in dev are in the /assets folder anyway
#
# 2. Stop using a concatenator that does tons of work checking for semicolons when
#     when rebuilding an asset

module FreedomPatches
  module SprocketsPatches
    def self.concat_javascript_sources(buf, source)
      if buf.bytesize > 0
        # CODE REMOVED HERE
        buf << ";" # unless string_end_with_semicolon?(buf)
        buf << "\n" # unless buf.end_with?("\n")
      end
      buf << source
    end

    if Rails.env.development? || Rails.env.test?
      Sprockets.register_bundle_metadata_reducer "application/javascript",
                                                 :data,
                                                 proc { +"" },
                                                 method(:concat_javascript_sources)
    end
  end
end

if Rails.env.development? || Rails.env.test?
  ActiveSupport.on_load(:action_view) do
    def compute_asset_path(source, _options = {})
      "/assets/#{source}"
    end
    alias_method :public_compute_asset_path, :compute_asset_path
  end
end

# By default, the Sprockets DirectiveProcessor introduces a newline between possible 'header' comments
# and the rest of the JS file. (https://github.com/rails/sprockets/blob/f4d3dae71e/lib/sprockets/directive_processor.rb#L121)
# This causes sourcemaps to be offset by 1 line, and therefore breaks browser tooling.
# We know that Ember-Cli assets do not use Sprockets directives, so we can totally bypass the DirectiveProcessor for those files.
Sprockets::DirectiveProcessor.prepend(
  Module.new do
    def process_source(source)
      return source, [] if EmberCli.is_ember_cli_asset?(File.basename(@filename))
      super
    end
  end,
)

# Skip digest path for workbox assets. They are already in a folder with a digest in the name.
Sprockets::Asset.prepend(
  Module.new do
    def digest_path
      return logical_path if logical_path.match?(%r{^workbox-.*/})
      super
    end
  end,
)
