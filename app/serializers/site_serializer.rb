# frozen_string_literal: true

class SiteSerializer < ApplicationSerializer
  include NavigationMenuTagsMixin

  attributes(
    :default_archetype,
    :notification_types,
    :post_types,
    :user_tips,
    :trust_levels,
    :groups,
    :filters,
    :periods,
    :top_menu_items,
    :anonymous_top_menu_items,
    :uncategorized_category_id, # this is hidden so putting it here
    :user_field_max_length,
    :post_action_types,
    :topic_flag_types,
    :can_create_tag,
    :can_tag_topics,
    :can_tag_pms,
    :tags_filter_regexp,
    :top_tags,
    :navigation_menu_site_top_tags,
    :can_associate_groups,
    :wizard_required,
    :topic_featured_link_allowed_category_ids,
    :user_themes,
    :user_color_schemes,
    :default_dark_color_scheme,
    :censored_regexp,
    :shared_drafts_category_id,
    :custom_emoji_translation,
    :watched_words_replace,
    :watched_words_link,
    :categories,
    :markdown_additional_options,
    :hashtag_configurations,
    :hashtag_icons,
    :anonymous_default_navigation_menu_tags,
    :anonymous_sidebar_sections,
    :whispers_allowed_groups_names,
    :denied_emojis,
    :tos_url,
    :privacy_policy_url,
    :system_user_avatar_template,
    :lazy_load_categories,
    :valid_flag_applies_to_types,
  )

  has_many :archetypes, embed: :objects, serializer: ArchetypeSerializer
  has_many :user_fields, embed: :objects, serializer: UserFieldSerializer
  has_many :auth_providers, embed: :objects, serializer: AuthProviderSerializer
  has_many :anonymous_sidebar_sections, embed: :objects, serializer: SidebarSectionSerializer

  def user_themes
    cache_fragment("user_themes") do
      Theme
        .where("id = :default OR user_selectable", default: SiteSetting.default_theme_id)
        .order("lower(name)")
        .pluck(:id, :name, :color_scheme_id)
        .map do |id, n, cs|
          {
            theme_id: id,
            name: n,
            default: id == SiteSetting.default_theme_id,
            color_scheme_id: cs,
          }
        end
        .as_json
    end
  end

  def user_color_schemes
    cache_fragment("user_color_schemes") do
      schemes = ColorScheme.includes(:color_scheme_colors).where("user_selectable").order(:name)
      ActiveModel::ArraySerializer.new(
        schemes,
        each_serializer: ColorSchemeSelectableSerializer,
      ).as_json
    end
  end

  def default_dark_color_scheme
    ColorSchemeSerializer.new(
      ColorScheme.find_by_id(SiteSetting.default_dark_mode_color_scheme_id),
      root: false,
    ).as_json
  end

  def groups
    cache_anon_fragment("group_names") do
      object
        .groups
        .order(:name)
        .select(:id, :name, :flair_icon, :flair_upload_id, :flair_bg_color, :flair_color)
        .map do |g|
          {
            id: g.id,
            name: g.name,
            flair_url: g.flair_url,
            flair_bg_color: g.flair_bg_color,
            flair_color: g.flair_color,
          }
        end
        .as_json
    end
  end

  def post_action_types
    Discourse
      .cache
      .fetch("post_action_types_#{I18n.locale}") do
        if PostActionType.overridden_by_plugin_or_skipped_db?
          types = ordered_flags(PostActionType.types.values)
          ActiveModel::ArraySerializer.new(types).as_json
        else
          ActiveModel::ArraySerializer.new(
            Flag.unscoped.order(:position).where(score_type: false).all,
            each_serializer: FlagSerializer,
            target: :post_action,
            used_flag_ids: Flag.used_flag_ids,
          ).as_json
        end
      end
  end

  def topic_flag_types
    Discourse
      .cache
      .fetch("post_action_flag_types_#{I18n.locale}") do
        if PostActionType.overridden_by_plugin_or_skipped_db?
          types = ordered_flags(PostActionType.topic_flag_types.values)
          ActiveModel::ArraySerializer.new(types, each_serializer: TopicFlagTypeSerializer).as_json
        else
          ActiveModel::ArraySerializer.new(
            Flag
              .unscoped
              .where("'Topic' = ANY(applies_to)")
              .where(score_type: false)
              .order(:position)
              .all,
            each_serializer: FlagSerializer,
            target: :topic_flag,
            used_flag_ids: Flag.used_flag_ids,
          ).as_json
        end
      end
  end

  def default_archetype
    Archetype.default
  end

  def post_types
    Post.types
  end

  def user_tips
    User.user_tips
  end

  def include_user_tips?
    SiteSetting.enable_user_tips
  end

  def filters
    Discourse.filters.map(&:to_s)
  end

  def periods
    TopTopic.periods.map(&:to_s)
  end

  def top_menu_items
    Discourse.top_menu_items.map(&:to_s)
  end

  def anonymous_top_menu_items
    Discourse.anonymous_top_menu_items.map(&:to_s)
  end

  def uncategorized_category_id
    SiteSetting.uncategorized_category_id
  end

  def user_field_max_length
    UserField.max_length
  end

  def can_create_tag
    scope.can_create_tag?
  end

  def can_tag_topics
    scope.can_tag_topics?
  end

  def can_tag_pms
    scope.can_tag_pms?
  end

  def can_associate_groups
    scope.can_associate_groups?
  end

  def include_can_associate_groups?
    scope.is_admin?
  end

  def include_tags_filter_regexp?
    SiteSetting.tagging_enabled
  end

  def tags_filter_regexp
    DiscourseTagging::TAGS_FILTER_REGEXP.source
  end

  def include_top_tags?
    Tag.include_tags?
  end

  def top_tags
    @top_tags ||= Tag.top_tags(guardian: scope)
  end

  def wizard_required
    true
  end

  def include_wizard_required?
    Wizard.user_requires_completion?(scope.user)
  end

  def include_topic_featured_link_allowed_category_ids?
    SiteSetting.topic_featured_link_enabled
  end

  def topic_featured_link_allowed_category_ids
    scope.topic_featured_link_allowed_category_ids
  end

  def censored_regexp
    WordWatcher.serialized_regexps_for_action(:censor, engine: :js)
  end

  def custom_emoji_translation
    Plugin::CustomEmoji.translations
  end

  def shared_drafts_category_id
    SiteSetting.shared_drafts_category.to_i
  end

  def include_shared_drafts_category_id?
    scope.can_see_shared_draft? && SiteSetting.shared_drafts_enabled?
  end

  def watched_words_replace
    WordWatcher.regexps_for_action(:replace, engine: :js)
  end

  def watched_words_link
    WordWatcher.regexps_for_action(:link, engine: :js)
  end

  def categories
    object.categories.map { |c| c.to_h }
  end

  def include_categories?
    object.categories.present?
  end

  def markdown_additional_options
    Site.markdown_additional_options
  end

  def hashtag_configurations
    HashtagAutocompleteService.contexts_with_ordered_types
  end

  def hashtag_icons
    HashtagAutocompleteService.data_source_icon_map
  end

  SIDEBAR_TOP_TAGS_TO_SHOW = 5

  def navigation_menu_site_top_tags
    if top_tags.present?
      tag_names = top_tags[0...SIDEBAR_TOP_TAGS_TO_SHOW]
      serialized = serialize_tags(Tag.where(name: tag_names))

      # Ensures order of top tags is preserved
      serialized.sort_by { |tag| tag_names.index(tag[:name]) }
    else
      []
    end
  end

  def include_navigation_menu_site_top_tags?
    SiteSetting.tagging_enabled
  end

  def anonymous_default_navigation_menu_tags
    @anonymous_default_navigation_menu_tags ||=
      begin
        tag_names =
          SiteSetting.default_navigation_menu_tags.split("|") -
            DiscourseTagging.hidden_tag_names(scope)

        serialize_tags(Tag.where(name: tag_names).order(:name))
      end
  end

  def include_anonymous_default_navigation_menu_tags?
    scope.anonymous? && SiteSetting.tagging_enabled &&
      SiteSetting.default_navigation_menu_tags.present? &&
      anonymous_default_navigation_menu_tags.present?
  end

  def include_anonymous_sidebar_sections?
    scope.anonymous?
  end

  def whispers_allowed_groups_names
    Group.where(id: SiteSetting.whispers_allowed_groups_map).pluck(:name)
  end

  def include_whispers_allowed_groups_names?
    scope.can_see_whispers?
  end

  def denied_emojis
    @denied_emojis ||= Emoji.denied
  end

  def include_denied_emojis?
    denied_emojis.present?
  end

  def tos_url
    Discourse.tos_url
  end

  def include_tos_url?
    tos_url.present?
  end

  def privacy_policy_url
    Discourse.privacy_policy_url
  end

  def include_privacy_policy_url?
    privacy_policy_url.present?
  end

  def system_user_avatar_template
    Discourse.system_user.avatar_template
  end

  def include_system_user_avatar_template?
    SiteSetting.show_user_menu_avatars
  end

  def lazy_load_categories
    true
  end

  def include_lazy_load_categories?
    scope.can_lazy_load_categories?
  end

  def valid_flag_applies_to_types
    Flag.valid_applies_to_types
  end

  def include_valid_flag_applies_to_types?
    scope.is_admin?
  end

  private

  def ordered_flags(flags)
    flags.map { |id| PostActionType.new(id: id) }
  end
end
