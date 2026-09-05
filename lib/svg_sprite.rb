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
        arrow-up-from-bracket
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
        code-branch
        comment
        comments
        compress
        copy
        crosshairs
        cube
        cubes
        desktop
        diagram-project
        dice
        discourse-amazon
        discourse-bell-exclamation
        discourse-bell-one
        discourse-bell-slash
        discourse-bookmark-clock
        discourse-chevron-collapse
        discourse-chevron-expand
        discourse-circle-minus
        discourse-circle-plus
        discourse-compress
        discourse-dnd
        discourse-emojis
        discourse-expand
        discourse-flask-check
        discourse-other-tab
        discourse-sidebar
        discourse-sparkles
        discourse-table
        discourse-text
        discourse-threads
        discourse-chat-search
        discourse-add-translation
        download
        discourse-h1
        discourse-h2
        discourse-h3
        discourse-h4
        discourse-h5
        earth-americas
        ellipsis
        ellipsis-vertical
        envelope
        expand
        eye
        eye-dropper
        eye-slash
        fab-android
        fab-apple
        fab-chrome
        fab-discord
        fab-discourse
        fab-edge
        fab-facebook
        fab-facebook-square
        fab-firefox-browser
        fab-github
        fab-google
        fab-instagram
        fab-internet-explorer
        fab-linkedin-in
        fab-linux
        fab-microsoft
        fab-markdown
        fab-opera
        fab-qq
        fab-safari
        fab-threads
        fab-threads-square
        fab-twitter
        fab-twitter-square
        fab-x-twitter
        fab-wikipedia-w
        fab-windows
        far-bell
        far-bell-slash
        far-bookmark
        far-calendar-plus
        far-chart-bar
        far-circle
        far-circle-dot
        far-circle-question
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
        filter-circle-xmark
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
        gif
        gift
        globe
        grip-lines
        grip-vertical
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
        nested-thread
        paintbrush
        palette
        paper-plane
        pause
        pen
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
        sign-hanging
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
        table-cells-minus
        table-cells-plus
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
        video
        wand-magic
        wrench
        xmark
      ],
    )

  THEME_SPRITE_VAR_NAME = "icons-sprite"

  ICON_SET_FIELD_NAME = "icon-set"

  ICON_SET_IGNORE_SETTING = "ignored_icons"

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
    @svg_files ||= Dir.glob("#{Rails.root.join("vendor/assets/svg-icons/**/*.svg")}")
  end

  def self.core_svgs
    @core_svgs ||=
      core_svgs_files.reduce({}) do |symbols, path|
        symbols.merge!(symbols_for(File.basename(path, ".svg"), File.read(path), strict: true))
      end
  end

  # Just used in tests
  def self.clear_plugin_svg_sprite_cache!
    @plugin_svgs_by_plugin = nil
    @icon_set_site_settings = nil
  end

  def self.plugin_svgs_by_plugin
    @plugin_svgs_by_plugin ||=
      Discourse
        .plugins
        .reduce({}) do |by_plugin, plugin|
          symbols =
            Dir
              .glob("#{File.dirname(plugin.path)}/svg-icons/*.svg")
              .reduce({}) do |s, path|
                s.merge!(symbols_for(File.basename(path, ".svg"), File.read(path), strict: true))
              end
          by_plugin[plugin.name] = symbols if symbols.present?
          by_plugin
        end
  end

  def self.theme_svgs_by_theme(theme_id)
    return {} if theme_id.blank?

    cache.defer_get_set_bulk(
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
          [_theme_id, symbols_for("theme_#{_theme_id}_#{upload_id}.svg", sprite, strict: false)]
        rescue => e
          Rails.logger.warn(
            "Bad XML in custom sprite in theme with ID=#{_theme_id}. Error info: #{e.inspect}",
          )
        end
        .compact
        .to_h
        .values_at(*theme_ids)
    end
  end

  # Excludes the declaring sprite: it is an alias source. `icon_set:` takes an
  # already-resolved set, or nil for none; :unresolved means look it up.
  def self.custom_svgs(theme_id, icon_set: :unresolved)
    set = icon_set == :unresolved ? active_icon_set(theme_id) : icon_set
    svgs = {}
    plugin_svgs_by_plugin.each do |plugin_name, symbols|
      svgs.merge!(symbols) if set.nil? || plugin_name != set["plugin"]
    end
    theme_svgs_by_theme(theme_id).each do |sprite_theme_id, symbols|
      next if symbols.nil?
      next if set && sprite_theme_id == set["theme_id"]
      svgs.merge!(symbols)
    end
    svgs
  end

  def self.all_icons(theme_id = nil)
    get_set_cache("icons_#{Theme.transform_ids(theme_id).join(",")}") do
      Set
        .new()
        .merge(explicitly_requested_icons(theme_id))
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
    icon_set = active_icon_set(theme_id)
    svgs = core_svgs
    if icon_set
      # Same write order as `bundle`, but resolves every map key, not just the
      # requested ones: the picker lists not-yet-bundled icons from here.
      source = icon_set_source(theme_id, icon_set)
      svgs = apply_icon_set(svgs.dup, icon_set, source)
      svgs.merge!(requested_source_glyphs(svgs, theme_id, source))
      svgs.merge!(custom_svgs(theme_id, icon_set: icon_set))
    elsif theme_id.present?
      svgs = svgs.merge(custom_svgs(theme_id, icon_set: nil))
    end
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

    icon_set = active_icon_set(theme_id)
    if icon_set
      # custom_svgs last, so an explicit sprite override still wins.
      svgs = core_svgs.slice(*icons)
      source = icon_set_source(theme_id, icon_set)
      apply_icon_set(svgs, icon_set, source, icons)
      svgs.merge!(requested_source_glyphs(svgs, theme_id, source))
      svgs.merge!(custom_svgs(theme_id, icon_set: icon_set))
      svg_subset << svgs.values.join
    else
      # Append rather than merge to preserve the long-standing emission for
      # sites without an icon set: id collisions ship both symbols and the
      # default (first in document order) wins client-side.
      svg_subset << core_svgs.slice(*icons).values.join
      svg_subset << custom_svgs(theme_id, icon_set: nil).values.join
    end

    svg_subset << "</svg>"
  end

  # Gaps only. Overriding anything already resolved would let a set with
  # unprefixed glyph ids shadow every core icon it shares a name with.
  def self.requested_source_glyphs(svgs, theme_id, source)
    source.slice(*(explicitly_requested_icons(theme_id) - svgs.keys))
  end

  # Mutates and returns `svgs`. `names` bounds it to what the caller emits.
  def self.apply_icon_set(svgs, icon_set, source, names = icon_set["map"].keys)
    names.each do |name|
      target = icon_set_target(icon_set, name)
      svgs[name] = alias_symbol_id(source[target], name) if target && source[target]
    end
    svgs
  end

  def self.icon_set_target(icon_set, name)
    mapped = icon_set["map"][name]
    return nil if !mapped.is_a?(String)
    return nil if icon_set["ignored"]&.include?(name)
    values = icon_set["values"] || {}
    mapped.gsub(/\{([\w-]+)\}/) { values[$1].to_s }
  end

  def self.icon_set_source(theme_id, icon_set)
    if icon_set["plugin"]
      plugin_svgs_by_plugin[icon_set["plugin"]] || {}
    else
      theme_svgs_by_theme(theme_id)[icon_set["theme_id"]] || {}
    end
  end

  # The leading \s matches ` id="..."` whole, so `data-id` is not mistaken for
  # it; the block form stops `name` being read as a back-reference.
  def self.alias_symbol_id(symbol, name)
    symbol.sub(/(<symbol\b[^>]*?\s)id="[^"]*"/) { "#{$1}id=\"#{name}\"" }
  end

  def self.active_icon_set(theme_id)
    theme_ids = Theme.transform_ids(theme_id)
    # The "no icon set" sentinel must stay a Hash: values round-trip through
    # MessageBus JSON to other app servers, where a Symbol would arrive as a
    # String. `{}.presence` is nil.
    result =
      get_set_cache("icon_set_#{theme_ids.join(",")}") do
        icon_set = build_icon_set(theme_ids) || build_plugin_icon_set
        log_unresolved_icon_set_targets(theme_id, icon_set) if icon_set
        icon_set || {}
      end
    result.presence
  end

  def self.log_unresolved_icon_set_targets(theme_id, icon_set)
    source = icon_set_source(theme_id, icon_set)
    missing =
      icon_set["map"].keys.filter_map do |name|
        target = icon_set_target(icon_set, name)
        name if target && !source.key?(target)
      end
    return if missing.empty?

    # Unbound placeholders first: one bad setting takes out every icon using it.
    unbound = (icon_set["values"] || {}).select { |_, value| value.blank? }.keys
    cause =
      if unbound.present?
        " (no value for #{unbound.join(", ")} - is a setting of that name declared?)"
      else
        ""
      end
    example = icon_set_target(icon_set, missing.first)

    Rails.logger.warn(
      "Icon set (#{icon_set["plugin"] || "theme #{icon_set["theme_id"]}"}): " \
        "no matching sprite glyph for #{missing.size} mapped " \
        "#{"icon".pluralize(missing.size)}#{cause}, falling back to the default. " \
        "#{missing.first} resolved to \"#{example}\"; also #{missing[1, 19].to_a.join(", ")}",
    )
  end

  def self.icon_set_fields
    # Target and type too, so a theme file merely named "icon-set" can't fake it.
    ThemeField.where(
      name: ICON_SET_FIELD_NAME,
      target_id: Theme.targets[:common],
      type_id: ThemeField.types[:json],
    )
  end

  def self.build_icon_set(theme_ids)
    fields = icon_set_fields.find_by_theme_ids(theme_ids).where.not(value: nil).to_a
    declarations =
      fields.filter_map do |field|
        declaration = parse_icon_set_field(field)
        [field, declaration] if declaration
      end
    return nil if declarations.empty?

    field, decl = declarations.first

    if declarations.size > 1
      Rails.logger.warn(
        "Multiple themes declare an icon set " \
          "(theme ids #{declarations.map { |item| item.first.theme_id }.join(", ")}); " \
          "using theme #{field.theme_id}",
      )
    end

    decl["theme_id"] = field.theme_id
    # A fresh settings parse, not cached_settings: the cache-expiry hook on
    # ThemeSetting fires before the theme caches are cleared, so a cached read
    # here could re-cache a stale value.
    settings = field.theme&.settings || {}
    decl["values"] = icon_set_placeholders(decl["map"]).index_with do |setting|
      settings[setting.to_sym]&.value
    end
    if (ignored = settings[icon_set_ignore_setting(decl).to_sym]&.value)
      decl["ignored"] = ignored.to_s.split("|").map(&:strip)
    end

    decl
  end

  def self.parse_icon_set_field(field)
    return nil if field.value.blank?
    decl =
      begin
        JSON.parse(field.value)
      rescue JSON::ParserError
        nil
      end
    return nil unless decl.is_a?(Hash) && decl["map"].is_a?(Hash)
    decl["map"] = sanitize_icon_set_map(decl["map"])
    decl["map"].present? ? decl : nil
  end

  # The injection guard: names are spliced into <symbol id> attributes, and
  # svgs_for aliases every map key, so a bad name here reaches the icon picker,
  # which renders the symbol as trusted HTML. Import raises instead of dropping.
  def self.sanitize_icon_set_map(map)
    map.select { |name, glyph| valid_icon_name?(name) && glyph.is_a?(String) }
  end

  # Dots are tolerated so the dotted REPLACEMENTS names in icon-library.js pass
  # validation rather than erroring on import; mapping one is still inert,
  # because they resolve to a canonical icon before the sprite is consulted.
  def self.valid_icon_name?(name)
    name.is_a?(String) && name.match?(/\A[\w.-]+\z/)
  end

  def self.build_plugin_icon_set(registrations = DiscoursePluginRegistry.icon_sets)
    decls = registrations.filter_map { |registered| plugin_icon_set_decl(registered) }
    return nil if decls.empty?

    if decls.size > 1
      Rails.logger.warn(
        "Multiple plugins declare an icon set (#{decls.map { |d| d["plugin"] }.join(", ")}); " \
          "using #{decls.first["plugin"]}",
      )
    end
    decls.first
  end

  def self.plugin_icon_set_decl(registered)
    map = registered[:map]
    map = read_plugin_icon_map(registered) if map.is_a?(String)
    return nil if !map.is_a?(Hash)
    # Symbol keys are idiomatic in plugin code; normalize before sanitizing.
    map = sanitize_icon_set_map(map.transform_keys(&:to_s))
    return nil if map.empty?

    values =
      icon_set_placeholders(map).index_with do |setting|
        SiteSetting.public_send(setting) if plugin_setting?(registered, setting)
      end
    decl = { "map" => map, "values" => values, "plugin" => registered[:plugin_name] }
    if (setting = registered[:ignore_setting].to_s).present? && plugin_setting?(registered, setting)
      decl["ignored"] = SiteSetting.public_send(setting).to_s.split("|").map(&:strip)
    end
    decl
  end

  # Scoped to the plugin's own settings: unscoped, "ph-{title}-bell" would
  # interpolate the site title.
  def self.plugin_setting?(registered, setting)
    return false if !SiteSetting.has_setting?(setting)
    return true if SiteSetting.plugins[setting.to_sym] == registered[:plugin_name]

    Rails.logger.warn(
      "Icon set (#{registered[:plugin_name]}): \"#{setting}\" is not a setting of this " \
        "plugin and will not be read.",
    )
    false
  end

  def self.read_plugin_icon_map(registered)
    dir = File.realpath(registered[:plugin_dir])
    path = File.realpath(File.expand_path(registered[:map], dir))
    return nil if !path.start_with?(dir + File::SEPARATOR)
    return nil if !File.file?(path)
    JSON.parse(File.read(path))
  rescue JSON::ParserError, SystemCallError => e
    Rails.logger.warn(
      "Icon set (#{registered[:plugin_name]}): could not read map #{registered[:map]} " \
        "(#{e.message}); the set is inactive and the sprite ships unmapped.",
    )
    nil
  end

  def self.icon_set_placeholders(map)
    map.values.filter_map { |v| v.scan(/\{([\w-]+)\}/) if v.is_a?(String) }.flatten.uniq
  end

  # Declaring themes shadowed by another set in the same tree, as [name, id].
  # Enabled components only; a disabled one isn't in transform_ids.
  def self.inactive_icon_set_themes
    declaring = icon_set_fields.where.not(value: nil).pluck(:theme_id).uniq
    return [] if declaring.size < 2

    losers =
      Theme
        .where(component: false)
        .pluck(:id)
        .flat_map do |parent_id|
          active = active_icon_set(parent_id)
          next [] if active.nil? || active["theme_id"].nil?

          Theme
            .transform_ids(parent_id)
            .select { |id| declaring.include?(id) && id != active["theme_id"] }
        end
        .uniq

    Theme.where(id: losers).pluck(:name, :id)
  end

  def self.theme_declares_icon_set?(theme_id)
    icon_set_fields.exists?(theme_id: theme_id)
  end

  def self.icon_set_theme_setting?(theme_id, setting_name)
    field = icon_set_fields.find_by(theme_id: theme_id)
    declaration = parse_icon_set_field(field) if field
    return false if !declaration

    affected = icon_set_placeholders(declaration["map"]) << icon_set_ignore_setting(declaration)
    affected.include?(setting_name.to_s)
  end

  # The theme setting whose icons keep their default glyph. Declarable, like the
  # plugin side's `ignore_setting:`; the default keeps core out of a theme's
  # settings namespace only by convention, so a theme already using the name for
  # something else can point elsewhere.
  def self.icon_set_ignore_setting(decl)
    decl["ignore_setting"].presence || ICON_SET_IGNORE_SETTING
  end

  def self.icon_set_site_setting?(setting_name)
    icon_set_site_settings.include?(setting_name.to_s)
  end

  # Unfiltered on purpose: a disabled plugin's enabled setting must still
  # expire the cache when it is toggled.
  def self.icon_set_site_settings
    @icon_set_site_settings ||=
      DiscoursePluginRegistry
        ._raw_icon_sets
        .flat_map do |entry|
          map = entry[:value][:map]
          map = read_plugin_icon_map(entry[:value]) if map.is_a?(String)
          placeholders = map.is_a?(Hash) ? icon_set_placeholders(map) : []
          placeholders +
            [entry[:plugin].enabled_site_setting, entry[:value][:ignore_setting]].compact.map(
              &:to_s
            )
        end
        .to_set
  end

  def self.search(searched_icon)
    svgs_for(SiteSetting.default_theme_id)[searched_icon.strip] || false
  end

  def self.icon_picker_search(keyword, only_available, page:, per_page:, theme_id: nil)
    ids = picker_icon_ids(theme_id, only_available)

    if keyword.present?
      downcased_keyword = keyword.downcase
      ids = ids.lazy.select { |id| id.downcase.include?(downcased_keyword) }
    end

    ids = ids.drop(page * per_page).first(per_page + 1)

    has_more = ids.size > per_page
    ids = ids.take(per_page)

    missing = only_available ? [] : (ids - picker_icon_ids(theme_id, true)).to_set
    return { icons: ids.map { |id| { id: } }, has_more: } if missing.empty?

    symbols = svgs_for(theme_id)
    icons = ids.map { |id| missing.include?(id) ? { id:, symbol: symbols[id] } : { id: } }
    { icons:, has_more: }
  end

  def self.picker_icon_ids(theme_id, only_available)
    get_set_cache("picker_icon_ids_#{Theme.transform_ids(theme_id).join(",")}_#{only_available}") do
      symbols = svgs_for(theme_id)
      in_sprite = all_icons(theme_id).select { |id| symbols.key?(id) }

      only_available ? in_sprite : in_sprite + (symbols.keys - in_sprite).sort
    end
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
      # includes svg_icon_subset, icon type settings, icon properties of objects
      # type settings, and any settings containing _icon (incl. plugin settings)
      site_setting_icons = []

      SiteSetting.settings_hash.each do |key, value|
        next unless String === value

        if key.to_s.include?("_icon") || SiteSetting.type_supervisor.get_type(key) == :icon
          site_setting_icons |= value.split("|")
        elsif SiteSetting.type_supervisor.get_type(key) == :objects && value.present?
          schema = SiteSetting.type_supervisor.type_hash(key)[:schema]
          site_setting_icons |= objects_setting_icons(schema, JSON.parse(value)) if schema
        end
      end

      site_setting_icons
    end
  end

  def self.plugin_icons
    DiscoursePluginRegistry.svg_icons
  end

  def self.plugin_icon_sources
    DiscoursePluginRegistry.svg_icon_sources.flat_map { |source| Array(source.call) }
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
        settings = theme.cached_settings
        type_info = settings["theme_setting_type_info"] || {}

        settings.each do |key, value|
          if String === value
            if key.to_s.include?("_icon") || type_info.dig(key, :type) == "icon"
              theme_icon_settings |= value.split("|")
            end
          elsif type_info.dig(key, :type) == "objects" && value.is_a?(Array)
            schema = type_info.dig(key, :schema)
            theme_icon_settings |= objects_setting_icons(schema, value) if schema
          end
        end
      end

    theme_icon_settings |= ThemeModifierHelper.new(theme_ids: theme_ids).svg_icons

    theme_icon_settings
  end

  # Icons asked for by name, rather than ones that merely exist in a sprite.
  # Cached because `bundle` consults it outside the `all_icons` block.
  def self.explicitly_requested_icons(theme_id)
    get_set_cache("explicit_icons_#{Theme.transform_ids(theme_id).join(",")}") do
      Set
        .new()
        .merge(settings_icons)
        .merge(plugin_icons)
        .merge(plugin_icon_sources)
        .merge(badge_icons)
        .merge(group_icons)
        .merge(theme_icons(theme_id))
        .filter_map { |icon| icon&.strip.presence }
    end
  end

  def self.objects_setting_icons(schema, objects)
    SchemaSettingsObjectValidator.property_values_of_type(schema:, objects:, type: "icon").grep(
      String,
    )
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
