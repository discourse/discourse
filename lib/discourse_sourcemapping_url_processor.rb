# frozen_string_literal: true

# This postprocessor rewrites `//sourceMappingURL=` comments to include the hashed filename of the map.
# As a side effect, the default implementation also replaces relative sourcemap URLs with absolute URLs, including the CDN domain.
# We want to preserve the relative nature of the URLs, so that compiled JS is portable across sites with differing CDN configurations.
class DiscourseSourcemappingUrlProcessor < Sprockets::Rails::SourcemappingUrlProcessor
  def self.sourcemap_asset_path(sourcemap_logical_path, context:)
    result = super(sourcemap_logical_path, context: context)
    if (File.basename(sourcemap_logical_path) === sourcemap_logical_path) ||
         sourcemap_logical_path.start_with?("plugins/")
      # If the original sourcemap reference is relative, keep it relative
      result = File.basename(result)
    end
    result
  end
end
