# frozen_string_literal: true

class ApplicationLayoutPreloader
  include ReadOnlyMixin

  def self.banner_json_cache
    @banner_json_cache ||= DistributedCache.new("banner_json")
  end

  def initialize(guardian:, theme_id:, theme_target:, login_method:)
    @guardian = guardian
    @theme_id = theme_id
    @theme_target = theme_target
    @login_method = login_method
    @preloaded = {}
  end

  def store_preloaded(key, json)
    # I dislike that there is a gsub as opposed to a gsub!
    #  but we can not be mucking with user input, I wonder if there is a way
    #  to inject this safety deeper in the library or even in AM serializer
    @preloaded[key] = json.gsub("</", "<\\/")
  end

  def preloaded_data
    preload_anonymous_data

    preload_upcoming_change_data(@guardian.user)

    if @guardian.authenticated?
      @guardian.user.sync_notification_channel_position
      preload_current_user_data
    end

    @preloaded
  end

  def banner_json
    return "{}" if !@guardian.authenticated? && SiteSetting.login_required?

    self
      .class
      .banner_json_cache
      .defer_get_set("json_#{I18n.locale}") do
        topic = Topic.where(archetype: Archetype.banner).first
        banner = topic.present? && !topic.category&.read_restricted? ? topic.banner(@guardian) : {}
        MultiJson.dump(banner)
      end
  end

  def custom_html_json
    data =
      if @theme_id.present?
        {
          top: Theme.lookup_field(@theme_id, @theme_target, "after_header"),
          footer: Theme.lookup_field(@theme_id, @theme_target, "footer"),
        }
      else
        {}
      end

    data.merge! DiscoursePluginRegistry.custom_html if DiscoursePluginRegistry.custom_html

    DiscoursePluginRegistry.html_builders.each do |name, _|
      if name.start_with?("client:")
        data[name.sub(/\Aclient:/, "")] = DiscoursePluginRegistry.build_html(name, self)
      end
    end

    MultiJson.dump(data)
  end

  private

  def preload_current_user_data
    @preloaded["currentUser"] = MultiJson.dump(
      CurrentUserSerializer.new(
        @guardian.user,
        scope: @guardian,
        root: false,
        login_method: @login_method,
      ),
    )

    report = TopicTrackingState.report(@guardian.user)
    serializer = TopicTrackingStateSerializer.new(report, scope: @guardian, root: false)
    hash = serializer.as_json

    @preloaded["topicTrackingStates"] = MultiJson.dump(hash[:data])
    @preloaded["topicTrackingStateMeta"] = MultiJson.dump(hash[:meta])

    if @guardian.is_admin?
      # This is used in the wizard so we can preload fonts using the FontMap JS API.
      @preloaded["fontMap"] = MultiJson.dump(load_font_map)

      # Used to show plugin-specific admin routes in the sidebar.
      @preloaded["visiblePlugins"] = MultiJson.dump(
        Discourse
          .plugins_sorted_by_name(enabled_only: false)
          .map do |plugin|
            {
              name: plugin.name.downcase,
              humanized_name: plugin.humanized_name,
              admin_route: plugin.full_admin_route,
              enabled: plugin.enabled?,
              description: plugin.metadata.about,
            }
          end,
      )
    end
  end

  def preload_anonymous_data
    check_readonly_mode if @readonly_mode.nil?
    @preloaded["site"] = Site.json_for(@guardian)
    @preloaded["siteSettings"] = SiteSetting.client_settings_json
    @preloaded["themeSiteSettingOverrides"] = SiteSetting.theme_site_settings_json(@theme_id)
    @preloaded["customHTML"] = custom_html_json
    @preloaded["banner"] = banner_json
    @preloaded["customEmoji"] = custom_emoji
    @preloaded["isReadOnly"] = @readonly_mode.to_json
    @preloaded["isStaffWritesOnly"] = @staff_writes_only_mode.to_json
    @preloaded["activatedThemes"] = activated_themes_json
    @preloaded["themeBlockLayouts"] = theme_block_layouts_json
    @preloaded["themeBlockLayoutMeta"] = theme_block_layout_meta_json
  end

  def preload_upcoming_change_data(user)
    @preloaded["upcomingChanges"] = SiteSetting
      .upcoming_change_site_settings
      .each_with_object({}) do |upcoming_change, hash|
        hash[upcoming_change] = UpcomingChanges.enabled_for_user?(upcoming_change, user)
      end
      .to_json
  end

  def activated_themes_json
    id = @theme_id
    return "{}" if id.blank?
    ids = Theme.transform_ids(id)
    Theme
      .where(id: ids)
      .each_with_object({}) do |theme, hash|
        hash[theme.id] = { name: theme.name, settings: theme.cached_settings }
      end
      .to_json
  end

  # Per-theme metadata for the active stack, keyed by theme id. The block-layout
  # resolver picks each outlet's owner by the maximum `stack_index` (the theme's
  # position in `Theme.transform_ids`, parent before components), so the
  # most-derived theme owns; consumers also read `is_git` / `name` / `component`.
  # Emitted separately because the site serializer's `user_themes` lacks
  # `remote_theme_id` and lists only user-selectable themes.
  #
  # `is_git` is derived from the presence of a `remote_url`, matching
  # `RemoteTheme#is_git?` — NOT merely from a non-nil `remote_theme_id`. A
  # locally zip/dir-imported theme has a `remote_theme` record with a blank
  # `remote_url`, which is editable (not Git-managed); keying on `remote_url`
  # lets such a theme correctly report `is_git: false`.
  def theme_block_layout_meta_json
    id = @theme_id
    return "{}" if id.blank?
    ids = Theme.transform_ids(id)
    return "{}" if ids.blank?

    info_by_id =
      Theme
        .where(id: ids)
        .joins("LEFT JOIN remote_themes ON remote_themes.id = themes.remote_theme_id")
        .pluck(:id, :name, :component, "remote_themes.remote_url")
        .to_h do |theme_id, name, component, remote_url|
          [theme_id, { name: name, component: component, is_git: remote_url.present? }]
        end

    meta = {}
    ids.each_with_index do |theme_id, index|
      info = info_by_id[theme_id]
      next if info.nil?
      meta[theme_id] = info.merge(stack_index: index)
    end
    meta.to_json
  end

  # Returns a JSON-serialised flat list of block_layout entries for the active
  # theme stack — one row per `(theme, outlet)` pair, ordered by
  # `Theme.transform_ids` (theme stack order). A boot-time initializer iterates
  # this list and calls `api.setLayoutLayer(outlet, "theme", layout, { themeId,
  # themeStackIndex })` for each. An outlet's owner is the theme with the minimum
  # stack index (the most ancestral theme — parent before components), resolved
  # client-side from the per-theme `stack_index` in `theme_block_layout_meta_json`.
  def theme_block_layouts_json
    id = @theme_id
    return "[]" if id.blank?
    ids = Theme.transform_ids(id)
    return "[]" if ids.blank?

    layouts = []
    fields =
      ThemeField
        .where(theme_id: ids, type_id: ThemeField.types[:block_layout])
        .order(:theme_id, :name)
        .pluck(:theme_id, :name, :value_baked, :error)

    # Re-order fields so that themes flow in stack order; within a theme,
    # fields stay alphabetical by outlet name (matters only for
    # determinism — outlet-vs-outlet precedence is independent).
    by_theme = fields.group_by { |row| row[0] }
    ids.each do |theme_id|
      next unless by_theme.key?(theme_id)
      by_theme[theme_id].each do |_, outlet, value_baked, error|
        # Skip fields that failed to bake — `value_baked` is nil and
        # `error` carries the reason. An applied layout that failed to bake
        # would render nothing for the outlet; better to fall through to
        # the underlying layer.
        next if value_baked.blank? || error.present?
        begin
          parsed = JSON.parse(value_baked)
        rescue JSON::ParserError
          next
        end
        layouts << {
          theme_id: theme_id,
          outlet: outlet,
          schema_version: parsed["schema_version"],
          layout: parsed["layout"],
          version_token: Themes::BlockLayoutVersion.token_for(value_baked),
        }
      end
    end

    layouts.to_json
  end

  def load_font_map
    DiscourseFonts
      .fonts
      .each_with_object({}) do |font, font_map|
        next if !font[:variants]
        font_map[font[:key]] = font[:variants].map do |v|
          {
            url: "#{Discourse.base_url}/fonts/#{v[:filename]}?v=#{DiscourseFonts::VERSION}",
            weight: v[:weight],
          }
        end
      end
  end

  def custom_emoji
    serializer = ActiveModel::ArraySerializer.new(Emoji.custom, each_serializer: EmojiSerializer)
    MultiJson.dump(serializer)
  end
end
