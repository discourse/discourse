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
    @preloaded[key] = json
  end

  def preloaded_data
    preload_anonymous_data

    if @guardian.authenticated?
      @guardian.user.sync_notification_channel_position
      preload_current_user_data
    end

    @preloaded
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
              admin_route: plugin.full_admin_route,
              enabled: plugin.enabled?,
            }
          end,
      )
    end
  end

  def preload_anonymous_data
    @preloaded["site"] = Site.json_for(@guardian)
    @preloaded["siteSettings"] = SiteSetting.client_settings_json
    @preloaded["customHTML"] = custom_html_json
    @preloaded["banner"] = banner_json
    @preloaded["customEmoji"] = custom_emoji
    @preloaded["isReadOnly"] = get_or_check_readonly_mode.to_json
    @preloaded["isStaffWritesOnly"] = get_or_check_staff_writes_only_mode.to_json
    @preloaded["activatedThemes"] = activated_themes_json
  end

  def activated_themes_json
    id = @theme_id
    return "{}" if id.blank?
    ids = Theme.transform_ids(id)
    Theme.where(id: ids).pluck(:id, :name).to_h.to_json
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

  def banner_json
    return "{}" if !@guardian.authenticated? && SiteSetting.login_required?

    self
      .class
      .banner_json_cache
      .defer_get_set("json") do
        topic = Topic.where(archetype: Archetype.banner).first
        banner = topic.present? ? topic.banner : {}
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
end
