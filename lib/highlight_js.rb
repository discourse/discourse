# frozen_string_literal: true

module HighlightJs
  VERSION = 1 # bump to invalidate caches following core changes

  def self.languages_dir
    @languages_dir ||= "#{VendoredAssets.path("highlightjs/languages")}/"
  end

  def self.languages
    langs = Dir.glob(languages_dir + "*.js").map { |path| File.basename(path)[0..-8] }

    langs.sort
  end

  def self.bundle(langs)
    lang_js =
      langs.filter_map do |lang|
        File.read(languages_dir + "#{lang}.min.js")
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
