# frozen_string_literal: true

module SvgSprite
  SVG_ICONS ||= Set.new([
    "adjust",
    "anchor",
    "angle-double-down",
    "angle-double-up",
    "angle-down",
    "angle-right",
    "angle-up",
    "archive",
    "arrows-alt-h",
    "arrow-down",
    "arrow-up",
    "arrow-left",
    "at",
    "backward",
    "ban",
    "bars",
    "bed",
    "bell-slash",
    "bold",
    "book",
    "bookmark",
    "briefcase",
    "calendar-alt",
    "caret-down",
    "caret-left",
    "caret-right",
    "caret-up",
    "certificate",
    "chart-bar",
    "chart-pie",
    "check",
    "check-circle",
    "check-square",
    "chevron-down",
    "chevron-right",
    "chevron-up",
    "circle",
    "code",
    "cog",
    "columns",
    "comment",
    "compress",
    "copy",
    "crosshairs",
    "cube",
    "desktop",
    "download",
    "ellipsis-h",
    "ellipsis-v",
    "envelope",
    "envelope-square",
    "exchange-alt",
    "exclamation-circle",
    "exclamation-triangle",
    "external-link-alt",
    "expand",
    "fab-apple",
    "fab-facebook-f",
    "fab-facebook-square",
    "fab-github",
    "fab-google-plus-square",
    "fab-instagram",
    "fab-twitter",
    "fab-linux",
    "fab-twitter-square",
    "fab-windows",
    "fab-yahoo",
    "far-bell",
    "far-bell-slash",
    "far-calendar-plus",
    "far-chart-bar",
    "far-check-square",
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
    "far-moon",
    "far-smile",
    "far-square",
    "far-sun",
    "far-thumbs-down",
    "far-thumbs-up",
    "far-trash-alt",
    "fast-backward",
    "fast-forward",
    "file",
    "file-alt",
    "filter",
    "flag",
    "folder",
    "folder-open",
    "forward",
    "gavel",
    "globe",
    "globe-americas",
    "hand-point-right",
    "heading",
    "heart",
    "home",
    "info-circle",
    "italic",
    "key",
    "link",
    "list",
    "list-ol",
    "list-ul",
    "lock",
    "map-marker-alt",
    "magic",
    "microphone-slash",
    "minus",
    "minus-circle",
    "mobile-alt",
    "paint-brush",
    "paper-plane",
    "pencil-alt",
    "plug",
    "plus",
    "plus-circle",
    "plus-square",
    "power-off",
    "question",
    "question-circle",
    "quote-left",
    "quote-right",
    "redo",
    "reply",
    "rocket",
    "search",
    "share",
    "shield-alt",
    "shower",
    "signal",
    "sign-out-alt",
    "step-backward",
    "step-forward",
    "sync",
    "table",
    "tag",
    "tasks",
    "tv",
    "thermometer-three-quarters",
    "thumbs-down",
    "thumbs-up",
    "thumbtack",
    "times",
    "times-circle",
    "trash-alt",
    "undo",
    "unlink",
    "unlock",
    "unlock-alt",
    "upload",
    "user",
    "user-plus",
    "user-secret",
    "user-times",
    "users",
    "wrench"
  ])

  FA_ICON_MAP = { 'far fa-' => 'far-', 'fab fa-' => 'fab-', 'fa-' => '' }

  def self.all_icons
    icons = SVG_ICONS.dup
    icons
      .merge(settings_icons)
      .merge(plugin_icons)
      .merge(badge_icons)
      .merge(group_icons)
      .merge(theme_icons)
  end

  def self.bundle
    icons = all_icons

    svg_subset = """
      <!--
      Font Awesome Free 5.4.1 by @fontawesome - https://fontawesome.com
      License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License)
      -->
      <svg xmlns='http://www.w3.org/2000/svg' style='display: none;'>
    """.dup

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
          sym.css('title').each { |t| t.remove }
          svg_subset << sym.to_xml
        end
      end
    end

    svg_subset << '</svg>'
  end

  def self.version
    icon_subset = all_icons.sort.join('|')
    (@svg_subset_cache ||= {})[icon_subset] ||=
      Digest::SHA1.hexdigest(icon_subset)
  end

  def self.path
    "/svg-sprite/#{Discourse.current_hostname}/#{version}.svg"
  end

  def self.settings_icons
    # includes svg_icon_subset and any settings containing _icon (incl. plugin settings)
    site_setting_icons = []
    SiteSetting.all.pluck(:name, :value).each do |setting|
      if setting[0].to_s.include?("_icon") && setting[1].present?
        site_setting_icons |= setting[1].split('|')
      end
    end

    site_setting_icons.each { |i| process(i) }
  end

  def self.plugin_icons
    DiscoursePluginRegistry.svg_icons.each { |icon| process(icon) }
  end

  def self.badge_icons
    Badge.all.pluck(:icon).uniq.each { |icon| process(icon) }
  end

  def self.group_icons
    Group.where("flair_url LIKE '%fa-%'").pluck(:flair_url).uniq.each { |icon| process(icon) }
  end

  def self.theme_icons
    theme_icon_settings = []

    Theme.all.each do |theme|
      theme&.included_settings&.each do |name, value|
        if name.to_s.include? "_icon"
          theme_icon_settings |= value.split('|')
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
