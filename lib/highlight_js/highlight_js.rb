module HighlightJs

  def self.languages
    Dir.glob(File.dirname(__FILE__) << "/assets/lang/*.js").map do |path|
      File.basename(path)[0..-4]
    end
  end

  def self.bundle(langs)
    path = File.dirname(__FILE__) << "/assets/"

    result = File.read(path + "highlight.js")
    langs.each do |lang|
      begin
        result << "\n" << File.read(path + "lang/#{lang}.js")
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
