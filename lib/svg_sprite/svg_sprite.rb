module SvgSprite
  def self.bundle
    require 'nokogiri'

    @svg_subset = """
      <!--
      Font Awesome Free 5.4.1 by @fontawesome - https://fontawesome.com
      License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License)
      -->
      <svg xmlns='http://www.w3.org/2000/svg' style='display: none;'>
    """

    Dir["#{Rails.root}/vendor/assets/svg-icons/fontawesome/*.svg"].each do |fname|
      svg_file = Nokogiri::XML(File.open(fname)) do |config|
        config.options = Nokogiri::XML::ParseOptions::NOBLANKS
      end

      svg_filename = "#{File.basename(fname, ".svg")}"

      svg_file.css('symbol').each do |sym|
        key = ''
        case svg_filename
        when "regular"
          key = 'far-'
        when "brands"
          key = 'fab-'
        end

        icon_id = key + sym.attr('id')

        if SiteSetting.svg_icon_subset.split('|').include? icon_id
          sym.attributes['id'].value = icon_id
          @svg_subset << sym.to_xml
        end
      end
    end

    @svg_subset << '</svg>'
  end

  def self.version(svg_subset)
    (@svg_subset_cache ||= {})[svg_subset] ||=
      Digest::SHA1.hexdigest(svg_subset)
  end

  def self.path
    "/svg-sprite/#{Discourse.current_hostname}/#{version SiteSetting.svg_icon_subset}.svg"
  end
end
