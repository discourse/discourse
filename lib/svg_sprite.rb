# frozen_string_literal: true
module SvgSprite
  SVG_ICONS =
    Set.new(
      %w[
        a
        address-book
        address-card
        align-left
        anchor
        angle-down
        angle-left
        angle-right
        angle-up
        angles-down
        angles-left
        angles-right
        angles-up
        arrow-down
        arrow-left
        arrow-right
        arrow-rotate-left
        arrow-rotate-right
        arrow-up
        arrows-rotate
        asterisk
        at
        backward
        backward-fast
        backward-step
        ban
        bars
        bars-staggered
        bed
        bell
        bell-slash
        bold
        book
        book-open-reader
        bookmark
        bookmark-delete
        box-archive
        briefcase
        bullseye
        calendar-days
        caret-down
        caret-left
        caret-right
        caret-up
        certificate
        chart-bar
        chart-pie
        check
        chevron-down
        chevron-left
        chevron-right
        chevron-up
        circle
        circle-check
        circle-chevron-down
        circle-exclamation
        circle-half-stroke
        circle-info
        circle-minus
        circle-plus
        circle-question
        circle-user
        circle-xmark
        clock
        clock-rotate-left
        cloud-arrow-down
        cloud-arrow-up
        code
        comment
        compress
        copy
        crosshairs
        cube
        desktop
        diagram-project
        discourse-amazon
        discourse-bell-exclamation
        discourse-bell-one
        discourse-bell-slash
        discourse-bookmark-clock
        discourse-chevron-collapse
        discourse-chevron-expand
        discourse-compress
        discourse-dnd
        discourse-emojis
        discourse-expand
        discourse-other-tab
        discourse-sidebar
        discourse-sparkles
        discourse-table
        discourse-text
        discourse-threads
        discourse-add-translation
        download
        earth-americas
        ellipsis
        ellipsis-vertical
        envelope
        eye
        fab-android
        fab-apple
        fab-chrome
        fab-discord
        fab-discourse
        fab-facebook
        fab-facebook-square
        fab-github
        fab-instagram
        fab-linkedin-in
        fab-linux
        fab-markdown
        fab-threads
        fab-threads-square
        fab-twitter
        fab-twitter-square
        fab-x-twitter
        fab-wikipedia-w
        fab-windows
        far-bell
        far-bell-slash
        far-calendar-plus
        far-chart-bar
        far-circle
        far-circle-dot
        far-clipboard
        far-clock
        far-comment
        far-comments
        far-copyright
        far-envelope
        far-eye
        far-eye-slash
        far-face-frown
        far-face-meh
        far-face-smile
        far-file-lines
        far-heart
        far-image
        far-moon
        far-pen-to-square
        far-rectangle-list
        far-square
        far-square-check
        far-star
        far-sun
        far-thumbs-down
        far-thumbs-up
        far-trash-can
        file
        file-lines
        filter
        flag
        flask
        folder
        folder-open
        font
        forward
        forward-fast
        forward-step
        gavel
        gear
        gift
        globe
        grip-lines
        hand-point-right
        handshake-angle
        hashtag
        heart
        hourglass-start
        house
        id-card
        image
        images
        inbox
        italic
        key
        keyboard
        language
        layer-group
        left-right
        link
        link-slash
        list
        list-check
        list-ol
        list-ul
        location-dot
        lock
        magnifying-glass
        magnifying-glass-minus
        magnifying-glass-plus
        microphone-slash
        minus
        mobile-screen-button
        moon
        paintbrush
        palette
        paper-plane
        pause
        pencil
        play
        plug
        plus
        power-off
        puzzle-piece
        question
        quote-left
        quote-right
        reply
        right-from-bracket
        right-left
        right-to-bracket
        robot
        rocket
        rotate
        screwdriver-wrench
        scroll
        share
        shield-halved
        shuffle
        signal
        sliders
        spinner
        square-check
        square-envelope
        square-full
        square-plus
        star
        sun
        table
        table-cells
        table-columns
        tag
        tags
        temperature-three-quarters
        thumbs-down
        thumbs-up
        thumbtack
        tippy-rounded-arrow
        toggle-off
        toggle-on
        trash-can
        triangle-exclamation
        truck-medical
        unlock
        unlock-keyhole
        up-down
        up-right-from-square
        upload
        user
        user-check
        user-gear
        user-group
        user-pen
        user-plus
        user-secret
        user-shield
        user-xmark
        users
        wand-magic
        wrench
        xmark
      ],
    )

  THEME_SPRITE_VAR_NAME = "icons-sprite"

  MAX_THEME_SPRITE_SIZE = 1024.kilobytes

  def self.preload
    settings_icons
    group_icons
    badge_icons
  end

  def self.symbols_for(svg_filename, sprite, strict:)
    if strict
      Nokogiri.XML(sprite) { |config| config.options = Nokogiri::XML::ParseOptions::NOBLANKS }
    else
      Nokogiri.XML(sprite)
    end.css("symbol")
      .filter_map do |sym|
        icon_id = prepare_symbol(sym, svg_filename)
        if icon_id.present?
          sym.attributes["id"].value = icon_id
          sym.css("title").each(&:remove)
          [icon_id, sym.to_xml]
        end
      end
      .to_h
  end

  def self.core_svgs_files
    @svg_files ||= Dir.glob("#{Rails.root}/vendor/assets/svg-icons/**/*.svg")
  end

  def self.core_svgs
    @core_svgs ||=
      core_svgs_files.reduce({}) do |symbols, path|
        symbols.merge!(symbols_for(File.basename(path, ".svg"), File.read(path), strict: true))
      end
  end

  # Just used in tests
  def self.clear_plugin_svg_sprite_cache!
    @plugin_svgs = nil
  end

  def self.plugin_svgs
    @plugin_svgs ||=
      begin
        plugin_paths = []
        Discourse
          .plugins
          .map { |plugin| File.dirname(plugin.path) }
          .each { |path| plugin_paths << "#{path}/svg-icons/*.svg" }

        custom_sprite_paths = Dir.glob(plugin_paths)

        custom_sprite_paths.reduce({}) do |symbols, path|
          symbols.merge!(symbols_for(File.basename(path, ".svg"), File.read(path), strict: true))
        end
      end
  end

  def self.theme_svgs(theme_id)
    if theme_id.present?
      cache
        .defer_get_set_bulk(
          Theme.transform_ids(theme_id),
          lambda { |_theme_id| "theme_svg_sprites_#{_theme_id}" },
        ) do |theme_ids|
          theme_field_uploads =
            ThemeField.where(
              type_id: ThemeField.types[:theme_upload_var],
              name: THEME_SPRITE_VAR_NAME,
              theme_id: theme_ids,
            ).pluck(:upload_id)

          theme_sprites =
            ThemeSvgSprite.where(theme_id: theme_ids).pluck(:theme_id, :upload_id, :sprite)
          missing_sprites = (theme_field_uploads - theme_sprites.map(&:second))

          if missing_sprites.present?
            Rails.logger.warn(
              "Missing ThemeSvgSprites for theme #{theme_id}, uploads #{missing_sprites.join(", ")}",
            )
          end

          theme_sprites
            .map do |(_theme_id, upload_id, sprite)|
              begin
                [
                  _theme_id,
                  symbols_for("theme_#{_theme_id}_#{upload_id}.svg", sprite, strict: false),
                ]
              rescue => e
                Rails.logger.warn(
                  "Bad XML in custom sprite in theme with ID=#{_theme_id}. Error info: #{e.inspect}",
                )
              end
            end
            .compact
            .to_h
            .values_at(*theme_ids)
        end
        .values
        .compact
        .reduce({}) { |a, b| a.merge!(b) }
    else
      {}
    end
  end

  def self.custom_svgs(theme_id)
    plugin_svgs.merge(theme_svgs(theme_id))
  end

  def self.all_icons(theme_id = nil)
    get_set_cache("icons_#{Theme.transform_ids(theme_id).join(",")}") do
      Set
        .new()
        .merge(settings_icons)
        .merge(plugin_icons)
        .merge(badge_icons)
        .merge(group_icons)
        .merge(theme_icons(theme_id))
        .merge(custom_icons(theme_id))
        .delete_if { |i| i.blank? || i.include?("/") }
        .map!(&:strip)
        .merge(SVG_ICONS)
        .sort
    end
  end

  def self.version(theme_id = nil)
    get_set_cache("version_#{Theme.transform_ids(theme_id).join(",")}") do
      Digest::SHA1.hexdigest(bundle(theme_id))
    end
  end

  def self.path(theme_id = nil)
    "/svg-sprite/#{Discourse.current_hostname}/svg-#{theme_id}-#{version(theme_id)}.js"
  end

  def self.expire_cache
    cache&.clear
  end

  def self.svgs_for(theme_id)
    svgs = core_svgs
    svgs = svgs.merge(custom_svgs(theme_id)) if theme_id.present?
    svgs
  end

  def self.bundle(theme_id = nil)
    icons = all_icons(theme_id)

    svg_subset =
      "" \
        "<!--
Discourse SVG subset of Font Awesome Free by @fontawesome - https://fontawesome.com
License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License)
-->
<svg xmlns='http://www.w3.org/2000/svg' style='display: none;'>
" \
        "".dup

    svg_subset << core_svgs.slice(*icons).values.join
    svg_subset << custom_svgs(theme_id).values.join

    svg_subset << "</svg>"
  end

  def self.search(searched_icon)
    svgs_for(SiteSetting.default_theme_id)[searched_icon.strip] || false
  end

  def self.icon_picker_search(keyword, only_available = false)
    symbols = svgs_for(SiteSetting.default_theme_id)
    symbols.slice!(*all_icons(SiteSetting.default_theme_id)) if only_available
    symbols.reject! { |icon_id, _sym| !icon_id.include?(keyword) } if keyword.present?
    symbols.sort_by(&:first).map { |id, symbol| { id:, symbol: } }
  end

  # For use in no_ember .html.erb layouts
  def self.raw_svg(name)
    get_set_cache("raw_svg_#{name}") do
      symbol = search(name)
      break "" unless symbol
      symbol = Nokogiri.XML(symbol).children.first
      symbol.name = "svg"
      <<~HTML
        <svg class="fa d-icon svg-icon svg-node" aria-hidden="true">#{symbol}</svg>
      HTML
    end.html_safe
  end

  def self.theme_sprite_variable_name
    THEME_SPRITE_VAR_NAME
  end

  def self.prepare_symbol(symbol, svg_filename = nil)
    icon_id = symbol.attr("id")

    case svg_filename
    when "regular"
      icon_id = icon_id.prepend("far-")
    when "brands"
      icon_id = icon_id.prepend("fab-")
    end

    icon_id
  end

  def self.settings_icons
    get_set_cache("settings_icons") do
      # includes svg_icon_subset and any settings containing _icon (incl. plugin settings)
      site_setting_icons = []

      SiteSetting.settings_hash.select do |key, value|
        site_setting_icons |= value.split("|") if key.to_s.include?("_icon") && String === value
      end

      site_setting_icons
    end
  end

  def self.plugin_icons
    DiscoursePluginRegistry.svg_icons
  end

  def self.badge_icons
    get_set_cache("badge_icons") { Badge.pluck(:icon).uniq }
  end

  def self.group_icons
    get_set_cache("group_icons") { Group.pluck(:flair_icon).uniq }
  end

  def self.theme_icons(theme_id)
    return [] if theme_id.blank?

    theme_icon_settings = []
    theme_ids = Theme.transform_ids(theme_id)

    # Need to load full records for default values
    Theme
      .where(id: theme_ids)
      .each do |theme|
        _settings =
          theme.cached_settings.each do |key, value|
            if key.to_s.include?("_icon") && String === value
              theme_icon_settings |= value.split("|")
            end
          end
      end

    theme_icon_settings |= ThemeModifierHelper.new(theme_ids: theme_ids).svg_icons

    theme_icon_settings
  end

  def self.custom_icons(theme_id)
    # Automatically register icons in sprites added via themes or plugins
    custom_svgs(theme_id).keys
  end

  def self.get_set_cache(key, &block)
    cache.defer_get_set(key, &block)
  end

  def self.cache
    @cache ||= DistributedCache.new("svg_sprite")
  end
end
