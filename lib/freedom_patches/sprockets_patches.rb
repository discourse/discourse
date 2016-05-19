# This contains two patches to make sprockets more tolerable in dev
#
# 1. Stop computing asset paths which triggers sprockets to do mountains of work
#     All our assets in dev are in the /assets folder anyway
#
# 2. Stop using a concatenator that does tons of work checking for semicolons when
#     when rebuilding an asset

if Rails.env == "development"
  module ActionView::Helpers::AssetUrlHelper

    def asset_path(source, options = {})
      source = source.to_s
      return "" unless source.present?
      return source if source =~ URI_REGEXP

      tail, source = source[/([\?#].+)$/], source.sub(/([\?#].+)$/, '')

      if extname = compute_asset_extname(source, options)
        source = "#{source}#{extname}"
      end

      if source[0] != ?/
       # CODE REMOVED
       # source = compute_asset_path(source, options)
       source = "/assets/#{source}"
      end

      relative_url_root = defined?(config.relative_url_root) && config.relative_url_root
      if relative_url_root
        source = File.join(relative_url_root, source) unless source.starts_with?("#{relative_url_root}/")
      end

      if host = compute_asset_host(source, options)
        source = File.join(host, source)
      end

      "#{source}#{tail}"
    end
    alias_method :path_to_asset, :asset_path # aliased to avoid conflicts with an asset_path named route
  end

  module ::SprocketHack
    def self.concat_javascript_sources(buf, source)
      if buf.bytesize > 0
        # CODE REMOVED HERE
        buf << ";" # unless string_end_with_semicolon?(buf)
        buf << "\n" # unless buf.end_with?("\n")
      end
      buf << source
    end
  end

  Sprockets.register_bundle_metadata_reducer 'application/javascript', :data, proc { "" }, ::SprocketHack.method(:concat_javascript_sources)

end
