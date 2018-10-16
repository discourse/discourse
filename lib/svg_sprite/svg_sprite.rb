module SvgSprite

  def self.bundle(icons)
    require 'nokogiri'

    @doc = Nokogiri::XML(File.open("#{Rails.root}/vendor/assets/svg-icons/fontawesome/regular.svg")) do |config|
      config.options = Nokogiri::XML::ParseOptions::NOBLANKS
    end

    @doc.css('symbol').each do |sym|
      unless icons.include? sym.attr('id')
        sym.remove
      end
    end

    @doc.to_xml
  end

  def self.version(lang_string)
    (@lang_string_cache ||= {})[lang_string] ||=
      Digest::SHA1.hexdigest(bundle lang_string.split("|"))
  end

  def self.path
    # "/highlight-js/#{Discourse.current_hostname}/#{version SiteSetting.highlighted_languages}.js"
  end
end
