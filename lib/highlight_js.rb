# frozen_string_literal: true

module HighlightJs
  HIGHLIGHTJS_DIR =
    "#{Rails.root}/app/assets/javascripts/discourse/node_modules/@highlightjs/cdn-assets/"
  VERSION = 1 # bump to invalidate caches following core changes

  def self.languages
    langs = Dir.glob(HIGHLIGHTJS_DIR + "languages/*.js").map { |path| File.basename(path)[0..-8] }

    langs.sort
  end

  def self.bundle(langs)
    lang_js =
      langs.filter_map do |lang|
        File.read(HIGHLIGHTJS_DIR + "languages/#{lang}.min.js")
      rescue Errno::ENOENT
        # no file, don't care
      end

    <<~JS
      export default function registerLanguages(hljs) {
        #{lang_js.join("\n")}
      }
    JS
  end

  def self.cache
    @lang_string_cache ||= {}
  end

  def self.version(lang_string)
    cache_info = cache[RailsMultisite::ConnectionManagement.current_db]

    return cache_info[:digest] if cache_info&.[](:lang_string) == lang_string

    cache_info = {
      lang_string: lang_string,
      digest:
        Digest::SHA1.hexdigest(
          bundle(lang_string.split("|")) + "|#{VERSION}|#{GlobalSetting.asset_url_salt}",
        ),
    }

    cache[RailsMultisite::ConnectionManagement.current_db] = cache_info
    cache_info[:digest]
  end

  def self.path
    "/highlight-js/#{Discourse.current_hostname}/#{version SiteSetting.highlighted_languages}.js"
  end
end
