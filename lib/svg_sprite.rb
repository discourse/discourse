# frozen_string_literal: true

module SvgSprite
  SVG_ICONS ||=
    Set.new(
      %w[
        adjust
        address-book
        align-left
        ambulance
        anchor
        angle-double-down
        angle-double-up
        angle-double-right
        angle-double-left
        angle-down
        angle-right
        angle-up
        archive
        arrow-down
        arrow-left
        arrow-up
        arrows-alt-h
        arrows-alt-v
        at
        asterisk
        backward
        ban
        bars
        bed
        bell
        bell-slash
        bold
        book
        book-reader
        bookmark
        briefcase
        bullseye
        calendar-alt
        caret-down
        caret-left
        caret-right
        caret-up
        certificate
        chart-bar
        chart-pie
        check
        check-circle
        check-square
        chevron-circle-down
        chevron-down
        chevron-left
        chevron-right
        chevron-up
        circle
        cloud-upload-alt
        code
        cog
        columns
        comment
        compress
        copy
        crosshairs
        cube
        desktop
        discourse-amazon
        discourse-bell-exclamation
        discourse-bell-one
        discourse-bell-slash
        discourse-bookmark-clock
        discourse-compress
        discourse-emojis
        discourse-expand
        discourse-other-tab
        download
        ellipsis-h
        ellipsis-v
        envelope
        envelope-square
        exchange-alt
        exclamation-circle
        exclamation-triangle
        external-link-alt
        fab-android
        fab-apple
        fab-chrome
        fab-discord
        fab-discourse
        fab-facebook-square
        fab-facebook
        fab-github
        fab-instagram
        fab-linux
        fab-twitter
        fab-twitter-square
        fab-wikipedia-w
        fab-windows
        far-bell
        far-bell-slash
        far-calendar-plus
        far-chart-bar
        far-check-square
        far-circle
        far-clipboard
        far-clock
        far-comment
        far-comments
        far-copyright
        far-dot-circle
        far-edit
        far-envelope
        far-eye
        far-eye-slash
        far-file-alt
        far-frown
        far-heart
        far-image
        far-list-alt
        far-meh
        far-moon
        far-smile
        far-square
        far-star
        far-sun
        far-thumbs-down
        far-thumbs-up
        far-trash-alt
        fast-backward
        fast-forward
        file
        file-alt
        filter
        flag
        folder
        folder-open
        forward
        gavel
        gift
        globe
        globe-americas
        grip-lines
        hand-point-right
        hands-helping
        heart
        history
        home
        hourglass-start
        id-card
        image
        images
        inbox
        info-circle
        italic
        key
        keyboard
        layer-group
        link
        list
        list-ol
        list-ul
        lock
        magic
        map-marker-alt
        microphone-slash
        minus
        minus-circle
        mobile-alt
        moon
        paint-brush
        paper-plane
        pause
        pencil-alt
        play
        plug
        plus
        plus-circle
        plus-square
        power-off
        puzzle-piece
        question
        question-circle
        quote-left
        quote-right
        random
        redo
        reply
        rocket
        search
        search-plus
        search-minus
        share
        shield-alt
        sign-in-alt
        sign-out-alt
        signal
        sliders-h
        square-full
        star
        step-backward
        step-forward
        stream
        sync-alt
        sync
        table
        tag
        tags
        tasks
        thermometer-three-quarters
        thumbs-down
        thumbs-up
        thumbtack
        times
        times-circle
        toggle-off
        toggle-on
        trash-alt
        undo
        unlink
        unlock
        unlock-alt
        upload
        user
        user-cog
        user-edit
        user-friends
        user-plus
        user-secret
        user-shield
        user-times
        users
        wrench
        spinner
        tippy-rounded-arrow
      ],
    )

  FA_ICON_MAP = { "far fa-" => "far-", "fab fa-" => "fab-", "fas fa-" => "", "fa-" => "" }

  CORE_SVG_SPRITES = Dir.glob("#{Rails.root}/vendor/assets/svg-icons/**/*.svg")

  THEME_SPRITE_VAR_NAME = "icons-sprite"

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

  def self.core_svgs
    @core_svgs ||=
      CORE_SVG_SPRITES.reduce({}) do |symbols, path|
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
      theme_ids = Theme.transform_ids(theme_id)

      get_set_cache("theme_svg_sprites_#{theme_ids.join(",")}") do
        theme_field_uploads =
          ThemeField.where(
            type_id: ThemeField.types[:theme_upload_var],
            name: THEME_SPRITE_VAR_NAME,
            theme_id: theme_ids,
          ).pluck(:upload_id)

        theme_sprites = ThemeSvgSprite.where(theme_id: theme_ids).pluck(:upload_id, :sprite)
        missing_sprites = (theme_field_uploads - theme_sprites.map(&:first))

        if missing_sprites.present?
          Rails.logger.warn(
            "Missing ThemeSvgSprites for theme #{theme_id}, uploads #{missing_sprites.join(", ")}",
          )
        end

        theme_sprites.reduce({}) do |symbols, (upload_id, sprite)|
          begin
            symbols.merge!(symbols_for("theme_#{theme_id}_#{upload_id}.svg", sprite, strict: false))
          rescue => e
            Rails.logger.warn(
              "Bad XML in custom sprite in theme with ID=#{theme_id}. Error info: #{e.inspect}",
            )
          end

          symbols
        end
      end
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
        .map! { |i| process(i.dup) }
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
    searched_icon = process(searched_icon.dup)

    svgs_for(SiteSetting.default_theme_id)[searched_icon] || false
  end

  def self.icon_picker_search(keyword, only_available = false)
    icons = all_icons(SiteSetting.default_theme_id) if only_available

    symbols = svgs_for(SiteSetting.default_theme_id)
    symbols.slice!(*icons) if only_available
    symbols.reject! { |icon_id, sym| !icon_id.include?(keyword) } unless keyword.empty?
    symbols.sort_by(&:first).map { |icon_id, symbol| { id: icon_id, symbol: symbol } }
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

  def self.process(icon_name)
    icon_name = icon_name.strip
    FA_ICON_MAP.each { |k, v| icon_name = icon_name.sub(k, v) }
    icon_name
  end

  def self.get_set_cache(key, &block)
    cache.defer_get_set(key, &block)
  end

  def self.cache
    @cache ||= DistributedCache.new("svg_sprite")
  end
end
