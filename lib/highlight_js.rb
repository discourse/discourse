# frozen_string_literal: true

module HighlightJs
  HIGHLIGHTJS_DIR ||= "#{Rails.root}/app/assets/javascripts/node_modules/@highlightjs/cdn-assets/"

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
      export default function registerLanguages(hljs){
        #{lang_js.join("\n")}
      }
    JS
  end

  def self.version(lang_string)
    (@lang_string_cache ||= {})[lang_string] ||= Digest::SHA1.hexdigest(
      bundle lang_string.split("|")
    )
  end

  def self.path
    "/highlight-js/#{Discourse.current_hostname}/#{version SiteSetting.highlighted_languages}.js"
  end
end
