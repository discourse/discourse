# frozen_string_literal: true

module SvgSprite
  SVG_ICONS ||= Set.new([
    "anchor",
    "angle-double-down",
    "angle-double-up",
    "angle-down",
    "angle-up",
    "archive",
    "arrow-up",
    "at",
    "backward",
    "ban",
    "bars",
    "bed",
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
    "chevron-down",
    "chevron-right",
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
    "ellipsis-v",
    "envelope",
    "envelope-square",
    "exclamation-circle",
    "exclamation-triangle",
    "external-link-alt",
    "expand",
    "fab-apple",
    "fab-facebook-f",
    "fab-facebook-square",
    "fab-github",
    "fab-instagram",
    "fab-twitter",
    "fab-twitter-square",
    "fab-yahoo",
    "far-bell",
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
    "far-sun",
    "far-thumbs-down",
    "far-thumbs-up",
    "far-trash-alt",
    "fast-backward",
    "fast-forward",
    "file",
    "file-alt",
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
    "info-circle",
    "italic",
    "key",
    "link",
    "list",
    "list-ol",
    "list-ul",
    "lock",
    "magic",
    "microphone-slash",
    "minus",
    "mobile-alt",
    "paint-brush",
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
    "reply",
    "search",
    "share",
    "shield-alt",
    "signal",
    "sign-out-alt",
    "step-backward",
    "step-forward",
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
    icons = SVG_ICONS.dup
    icons.merge(SiteSetting.svg_icon_subset.split('|'))
    icons.merge(plugin_icons).merge(badge_icons).merge(group_icons).merge(theme_icons)
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
          @svg_subset << sym.to_xml
        end
      end
    end

    @svg_subset << '</svg>'
  end

  def self.version
    icon_subset = all_icons.sort.join('|')
    (@svg_subset_cache ||= {})[icon_subset] ||=
      Digest::SHA1.hexdigest(icon_subset)
  end

  def self.path
    "/svg-sprite/#{Discourse.current_hostname}/#{version}.svg"
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
