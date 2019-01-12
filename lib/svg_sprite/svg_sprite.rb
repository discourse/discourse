# frozen_string_literal: true

require_dependency 'distributed_cache'

module SvgSprite
  SVG_ICONS ||= Set.new([
    "adjust",
    "ambulance",
    "anchor",
    "angle-double-down",
    "angle-double-up",
    "angle-down",
    "angle-right",
    "angle-up",
    "archive",
    "arrows-alt-h",
    "arrows-alt-v",
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
    "discourse-compress",
    "discourse-expand",
    "download",
    "ellipsis-h",
    "ellipsis-v",
    "envelope",
    "envelope-square",
    "exchange-alt",
    "exclamation-circle",
    "exclamation-triangle",
    "external-link-alt",
    "fab-apple",
    "fab-android",
    "fab-discourse",
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
    "far-copyright",
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
    "play",
    "plug",
    "plus",
    "plus-circle",
    "plus-square",
    "power-off",
    "question",
    "question-circle",
    "quote-left",
    "quote-right",
    "random",
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

  FA_ICON_MAP = { 'far fa-' => 'far-', 'fab fa-' => 'fab-', 'fas fa-' => '', 'fa-' => '' }

  SVG_SPRITE_PATHS = Dir.glob(["#{Rails.root}/vendor/assets/svg-icons/**/*.svg",
                               "#{Rails.root}/plugins/*/svg-icons/*.svg"])

  def self.svg_sprite_cache
    @svg_sprite_cache ||= DistributedCache.new('svg_sprite')
  end

  def self.all_icons
    icons = Set.new()
    icons
      .merge(settings_icons)
      .merge(plugin_icons)
      .merge(badge_icons)
      .merge(group_icons)
      .merge(theme_icons)
      .delete_if { |i| i.blank? || i.include?("/") }
      .map! { |i| process(i.dup) }
      .merge(SVG_ICONS)
    icons
  end

  def self.rebuild_cache
    icons = all_icons
    svg_sprite_cache['icons'] = icons
    svg_sprite_cache['version'] = Digest::SHA1.hexdigest(icons.sort.join('|'))
  end

  def self.expire_cache
    svg_sprite_cache.clear
  end

  def self.version
    svg_sprite_cache['version'] || rebuild_cache
  end

  def self.bundle
    icons = svg_sprite_cache['icons'] || all_icons

    doc = File.open("#{Rails.root}/vendor/assets/svg-icons/fontawesome/solid.svg") { |f| Nokogiri::XML(f) }
    fa_license = doc.at('//comment()').text

    svg_subset = """<!--
Discourse SVG subset of #{fa_license}
-->
<svg xmlns='http://www.w3.org/2000/svg' style='display: none;'>
""".dup

    SVG_SPRITE_PATHS.each do |fname|
      svg_file = Nokogiri::XML(File.open(fname)) do |config|
        config.options = Nokogiri::XML::ParseOptions::NOBLANKS
      end

      svg_filename = "#{File.basename(fname, ".svg")}"

      svg_file.css('symbol').each do |sym|
        icon_id = prepare_symbol(sym, svg_filename)

        if icons.include? icon_id
          sym.attributes['id'].value = icon_id
          sym.css('title').each { |t| t.remove }
          svg_subset << sym.to_xml
        end
      end
    end

    svg_subset << '</svg>'
  end

  def self.search(searched_icon)
    searched_icon = process(searched_icon.dup)

    SVG_SPRITE_PATHS.each do |fname|
      svg_file = Nokogiri::XML(File.open(fname))
      svg_filename = "#{File.basename(fname, ".svg")}"

      svg_file.css('symbol').each do |sym|
        icon_id = prepare_symbol(sym, svg_filename)

        if searched_icon == icon_id
          sym.attributes['id'].value = icon_id
          sym.css('title').each { |t| t.remove }
          return sym.to_xml
        end
      end
    end

    return false
  end

  def self.prepare_symbol(symbol, svg_filename)
    icon_id = symbol.attr('id')

    case svg_filename
    when "regular"
      icon_id = icon_id.prepend('far-')
    when "brands"
      icon_id = icon_id.prepend('fab-')
    end

    icon_id
  end

  def self.path
    "/svg-sprite/#{Discourse.current_hostname}/svg-#{version}.js"
  end

  def self.settings_icons
    # includes svg_icon_subset and any settings containing _icon (incl. plugin settings)
    site_setting_icons = []

    SiteSetting.settings_hash.select do |key, value|
      if key.to_s.include?("_icon") && String === value
        site_setting_icons |= value.split('|')
      end
    end

    site_setting_icons
  end

  DiscourseEvent.on(:site_setting_saved) do |site_setting|
    expire_cache if site_setting.name.to_s.include?("_icon")
  end

  def self.plugin_icons
    DiscoursePluginRegistry.svg_icons
  end

  def self.badge_icons
    Badge.all.pluck(:icon).uniq
  end

  def self.group_icons
    Group.where("flair_url LIKE '%fa-%'").pluck(:flair_url).uniq
  end

  def self.theme_icons
    theme_icon_settings = []

    # Theme.all includes default values
    Theme.all.each do |theme|
      settings = theme.cached_settings.each do |key, value|
        if key.to_s.include?("_icon") && String === value
          theme_icon_settings |= value.split('|')
        end
      end
    end

    theme_icon_settings
  end

  def self.fa4_shim_file
    "#{Rails.root}/lib/svg_sprite/fa4-renames.json"
  end

  def self.fa4_to_fa5_names
    @db ||= File.open(fa4_shim_file, "r:UTF-8") { |f|  JSON.parse(f.read); }
  end

  def self.process(icon_name)
    icon_name = icon_name.strip
    FA_ICON_MAP.each { |k, v| icon_name.sub!(k, v) }
    fa4_to_fa5_names[icon_name] || icon_name
  end
end
