module SvgSprite
  SVG_ICONS ||= Set.new([
    "anchor",
    "angle-double-down",
    "angle-double-up",
    "angle-down",
    "angle-up",
    "archive",
    "arrow-up",
    "backward",
    "ban",
    "bars",
    "bold",
    "book",
    "bookmark",
    "calendar-alt",
    "caret-down",
    "caret-left",
    "caret-right",
    "caret-up",
    "certificate",
    "chart-bar",
    "chart-pie",
    "check",
    "chevron-down",
    "chevron-up",
    "circle",
    "code",
    "cog",
    "columns",
    "comment",
    "copy",
    "crosshairs",
    "cube",
    "desktop",
    "download",
    "ellipsis-h",
    "envelope",
    "envelope-square",
    "exclamation-circle",
    "exclamation-triangle",
    "expand",
    "fab-apple",
    "fab-facebook-square",
    "fab-twitter-square",
    "far-bell-slash",
    "far-calendar-plus",
    "far-circle",
    "far-clipboard",
    "far-clock",
    "far-comment",
    "far-dot-circle",
    "far-edit",
    "far-envelope",
    "far-eye",
    "far-eye-slash",
    "far-file-alt",
    "far-frown",
    "far-heart",
    "far-image",
    "far-list-alt",
    "far-smile",
    "far-square",
    "far-trash-alt",
    "fast-backward",
    "fast-forward",
    "file",
    "flag",
    "folder",
    "forward",
    "globe",
    "heading",
    "heart",
    "info-circle",
    "italic",
    "key",
    "link",
    "list",
    "list-ol",
    "list-ul",
    "lock",
    "microphone-slash",
    "minus",
    "mobile-alt",
    "paint-brush",
    "pencil-alt",
    "plus",
    "power-off",
    "question",
    "question-circle",
    "quote-left",
    "quote-right",
    "reply",
    "rocket",
    "search",
    "share",
    "shield-alt",
    "signal",
    "sign-out-alt",
    "sync",
    "table",
    "tasks",
    "thumbtack",
    "times",
    "times-circle",
    "trash-alt",
    "undo",
    "unlock",
    "upload",
    "user",
    "user-plus",
    "users",
    "wrench"
  ])

  FA_ICON_MAP = { 'far fa-' => 'far-', 'fab fa-' => 'fab-', 'fa-' => '' }

  def self.all_icons
    SVG_ICONS.merge(SiteSetting.svg_icon_subset.split('|'))
    SVG_ICONS.merge(DiscoursePluginRegistry.svg_icons)
    SVG_ICONS.merge(badge_icons)
    SVG_ICONS.merge(theme_icons)
  end

  def self.bundle
    require 'nokogiri'

    icons = all_icons

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
        icon_id = sym.attr('id')

        case svg_filename
        when "regular"
          icon_id = icon_id.prepend('far-')
        when "brands"
          icon_id = icon_id.prepend('fab-')
        end

        if icons.include? icon_id
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
    "/svg-sprite/#{Discourse.current_hostname}/#{version all_icons.to_s}.svg"
  end

  def self.badge_icons
    Badge.all.pluck(:icon).uniq.each { |i| process(i) }
  end

  def self.theme_icons
    theme_icon_settings = Array.new

    Theme.all.each do |theme|
      theme&.included_settings&.each do |name, value|
        if name.to_s.include? "_icon"
          theme_icon_settings |= [value]
        end
      end
    end

    theme_icon_settings.each { |i| process(i) }
  end

  def self.process(icon_name)
    FA_ICON_MAP.each { |k, v| icon_name.sub!(k, v) }
    icon_name
  end
end
