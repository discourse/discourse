# frozen_string_literal: true

module HighlightJs
  HIGHLIGHTJS_DIR ||= "#{Rails.root}/vendor/assets/javascripts/highlightjs/"

  def self.languages
    langs = Dir.glob(HIGHLIGHTJS_DIR + "languages/*.js").map do |path|
      File.basename(path)[0..-8]
    end

    langs.sort
  end

  def self.bundle(langs)
    result = File.read(HIGHLIGHTJS_DIR + "highlight.min.js")
    langs.each do |lang|
      begin
        result << "\n" << File.read(HIGHLIGHTJS_DIR + "languages/#{lang}.min.js")
      rescue Errno::ENOENT
        # no file, don't care
      end
    end

    result
  end

  def self.version(lang_string)
    (@lang_string_cache ||= {})[lang_string] ||=
      Digest::SHA1.hexdigest(bundle lang_string.split("|"))
  end

  def self.path
    "/highlight-js/#{Discourse.current_hostname}/#{version SiteSetting.highlighted_languages}.js"
  end
end
