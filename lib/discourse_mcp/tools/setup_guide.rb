# frozen_string_literal: true

module DiscourseMcp
  module Tools
    class GetSetupGuide
      VERSION = 1
      GUIDE_PATH = File.expand_path("../guides/site_setup.md", __dir__)
      REQUIRED_SCOPES = [Scopes::SITE_SETTINGS_READ].freeze
      MAX_CATEGORIES = 100
      MAX_COLOR_PALETTES = 50
      MAX_TEXT_LENGTH = 500
      SEEDED_CATEGORY_SETTINGS = %i[
        general_category_id
        meta_category_id
        staff_category_id
        uncategorized_category_id
      ].freeze
      SEEDED_TOPIC_SETTINGS = {
        welcome: :welcome_topic_id,
        guidelines: :guidelines_topic_id,
        terms_of_service: :tos_topic_id,
        privacy_policy: :privacy_topic_id,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          guide_version: OutputSchema::INTEGER,
          guide: OutputSchema::STRING,
          site: OutputSchema::OBJECT,
        )

      def self.call(arguments:, request_context:)
        request_context.guardian.ensure_is_admin!

        guide = File.read(GUIDE_PATH).gsub("{{base_url}}", Discourse.base_url)
        site = site_snapshot(request_context)
        AdminOnboarding.complete_step(
          UserHistory::ADMIN_ONBOARDING_AGENT_STEP,
          request_context.guardian.user,
        )

        {
          content: [
            { type: "text", text: guide },
            { type: "text", text: JSON.generate(guide_version: VERSION, site:) },
          ],
          structuredContent: {
            guide_version: VERSION,
            guide:,
            site:,
          },
          isError: false,
        }
      end

      def self.site_snapshot(request_context)
        theme = Theme.find_by(id: SiteSetting.default_theme_id)
        settings = {
          title: bounded(SiteSetting.title),
          site_description: bounded(SiteSetting.site_description),
          short_site_description: bounded(SiteSetting.short_site_description),
          default_locale: SiteSetting.default_locale,
          login_required: SiteSetting.login_required,
          invite_only: SiteSetting.invite_only,
          must_approve_users: SiteSetting.must_approve_users,
        }
        locale = SiteSetting.default_locale
        at_default =
          settings.keys.select do |name|
            SiteSetting.get(name) == SiteSetting.defaults.get(name, locale)
          end

        {
          url: Discourse.base_url,
          settings:,
          settings_at_default: at_default.map(&:to_s),
          logo_uploaded:
            SiteSetting.logo.present? && SiteSetting.logo.id != SiteSetting.defaults[:logo].to_i,
          default_theme: theme && theme_json(theme),
          color_palettes: color_palettes(theme),
          categories: categories(request_context.guardian),
          seeded_topics: seeded_topics,
          tools: Catalog.new(request_context:).list(:tool).map(&:identifier),
        }
      end
      private_class_method :site_snapshot

      def self.theme_json(theme)
        {
          id: theme.id,
          name: bounded(theme.name),
          color_palette_id: theme.color_scheme_id,
          dark_color_palette_id: theme.dark_color_scheme_id,
        }
      end
      private_class_method :theme_json

      def self.color_palettes(theme)
        ColorScheme
          .where(theme_id: [nil, theme&.id].uniq)
          .order(:id)
          .limit(MAX_COLOR_PALETTES)
          .map { |palette| { id: palette.id, name: bounded(palette.name) } }
      end
      private_class_method :color_palettes

      def self.categories(guardian)
        seeded_ids = SEEDED_CATEGORY_SETTINGS.map { |name| SiteSetting.get(name) }.to_set

        Category
          .secured(guardian)
          .includes(parent_category: :parent_category)
          .order(:id)
          .limit(MAX_CATEGORIES)
          .map do |category|
            {
              id: category.id,
              name: bounded(category.name),
              url: "#{Discourse.base_url_no_prefix}#{category.url}",
              security_url:
                "#{Discourse.base_url_no_prefix}#{category.slug_url_without_id}/edit/security",
              parent_category_id: category.parent_category_id,
              topic_count: category.topic_count,
              private: category.read_restricted,
              seeded: seeded_ids.include?(category.id),
            }
          end
      end
      private_class_method :categories

      def self.seeded_topics
        SEEDED_TOPIC_SETTINGS.each_with_object({}) do |(key, setting_name), topics|
          topic = Topic.find_by(id: SiteSetting.get(setting_name))
          next if topic.blank?

          topics[key] = { topic_id: topic.id, title: bounded(topic.title), url: topic.url }
        end
      end
      private_class_method :seeded_topics

      def self.bounded(value)
        value.to_s.truncate(MAX_TEXT_LENGTH)
      end
      private_class_method :bounded
    end
  end
end
