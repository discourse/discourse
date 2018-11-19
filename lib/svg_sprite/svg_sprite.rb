# frozen_string_literal: true

require_dependency 'distributed_cache'

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

  FA_ICON_MAP = { 'far fa-' => 'far-', 'fab fa-' => 'fab-', 'fa-' => '' }

  def self.svg_sprite_cache
    @svg_sprite_cache = DistributedCache.new('svg_sprite_version')
  end

  def self.all_icons
    icons = SVG_ICONS.dup
    icons
      .merge(settings_icons)
      .merge(plugin_icons)
      .merge(badge_icons)
      .merge(group_icons)
      .merge(theme_icons)
  end

  def self.rebuild_cache
    svg_sprite_cache['version'] = Digest::SHA1.hexdigest(all_icons.sort.join('|'))
  end

  def self.expire_cache
    svg_sprite_cache.clear
  end

  def self.version
    svg_sprite_cache['version'] || rebuild_cache
  end

  def self.bundle
    icons = all_icons

    doc = File.open("#{Rails.root}/vendor/assets/svg-icons/fontawesome/solid.svg") { |f| Nokogiri::XML(f) }
    fa_license = doc.at('//comment()').text

    svg_subset = """<!--
Discourse SVG subset of #{fa_license}
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

  def self.path
    "/svg-sprite/#{Discourse.current_hostname}/svg-#{version}.js"
  end

  def self.settings_icons
    # includes svg_icon_subset and any settings containing _icon (incl. plugin settings)
    site_setting_icons = []

    SiteSetting.settings_hash.select do |key, value|
      if key.to_s.include?("_icon") && value.present?
        site_setting_icons |= value.split('|').each { |i| process(i) }
      end
    end

    site_setting_icons
  end

  DiscourseEvent.on(:site_setting_saved) do |site_setting|
    expire_cache if site_setting.name.to_s.include?("_icon")
  end

  def self.plugin_icons
    DiscoursePluginRegistry.svg_icons.each { |icon| process(icon.dup) }
  end

  def self.badge_icons
    Badge.all.pluck(:icon).uniq.each { |icon| process(icon) }
  end

  def self.group_icons
    Group.where("flair_url LIKE '%fa-%'").pluck(:flair_url).uniq.each { |icon| process(icon) }
  end

  def self.theme_icons
    theme_icon_settings = []

    ThemeSetting.where("name LIKE '%_icon%'").pluck(:value).each do |icons|
      theme_icon_settings |= icons.split('|').each { |icon| process(icon) }
    end

    theme_icon_settings
  end

  def self.process(icon_name)
    FA_ICON_MAP.each { |k, v| icon_name.sub!(k, v) }
    icon_name
  end
end
