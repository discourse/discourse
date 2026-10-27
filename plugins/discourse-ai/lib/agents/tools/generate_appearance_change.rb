# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      # Builds readable light and dark palettes, and picks fonts, from brand
      # colors or from the administrator's own website. Nothing changes on the
      # site: the result is a signed draft that save_appearance_change saves
      # once an administrator approves it.
      class GenerateAppearanceChange < Tool
        MAX_NAME_LENGTH = 60
        WEBSITE_LOOKUPS_PER_HOUR = 10
        COLOR_PARAMETERS = %i[brand_color accent_color header_color].freeze
        FONT_PARAMETERS = { body_font: "base_font", heading_font: "heading_font" }.freeze

        # Stops generation with a message for the administrator.
        class Refusal < StandardError
        end

        def self.name
          "generate_appearance_change"
        end

        def self.signature
          fonts = DiscourseFonts.fonts.map { |font| font[:name] }.join(", ")

          {
            name:,
            description:
              "Builds readable light and dark palettes from brand colors, or from the administrator's main website, along with fonts if asked. Nothing on the site changes. Use save_appearance_change with the returned draft token to save it so it can be previewed.",
            parameters: [
              {
                name: "name",
                type: "string",
                required: true,
                description: "A short name for the palettes or theme, such as the brand's name",
              },
              {
                name: "brand_color",
                type: "string",
                description:
                  "The main brand color as hex, such as #635bff. Links and buttons use it.",
              },
              { name: "accent_color", type: "string", description: "A second brand color as hex" },
              {
                name: "header_color",
                type: "string",
                description:
                  "A header color as hex, only when the administrator wants a colored header",
              },
              {
                name: "website_url",
                type: "string",
                description:
                  "The administrator's main website, to take its brand colors and fonts from",
              },
              {
                name: "body_font",
                type: "string",
                description: "The font for text. One of: #{fonts}",
              },
              {
                name: "heading_font",
                type: "string",
                description: "The font for headings. One of: #{fonts}",
              },
              {
                name: "new_theme",
                type: "boolean",
                description:
                  "Save a separate theme instead of new palettes for the current theme. Only when the administrator asks for a new or separate theme.",
              },
            ],
          }
        end

        def self.custom_system_message
          <<~TEXT
            When an administrator asks to change the site's colors or fonts, or to match the look of their website, call generate_appearance_change. Pass website_url when they share a website. If it returns needs_brand_color, show the candidate colors and ask which one is their brand color, then call it again with brand_color and the same website_url. When it succeeds, say briefly what will change, including any colors adjusted so text stays readable, then call save_appearance_change with the exact draft token. Saving needs approval and doesn't change the site. Once it's saved, share the preview link and ask whether to make it live. Only call activate_appearance_change when the administrator asks to make it live; that needs approval too. To undo a change, find it with list_appearance_changes and call revert_appearance_change. Never say a change is live before activate_appearance_change succeeds. These tools only change colors and fonts. A new theme starts from Foundation, core's default design, so warn a site using another theme that its layout will change.
          TEXT
        end

        def self.available_for_context?(context)
          AppearanceAuthoring.visible?(context&.user)
        end

        def invoke
          refusal =
            AppearanceAuthoring.denial(
              user: context.user,
              phase: :generation,
              new_theme: new_theme?,
            )
          return error_response(refusal) if refusal

          name = draft_name
          colors = requested_colors
          fonts = requested_fonts
          design = website_design

          brand = colors[:brand_color]
          if brand.nil?
            return brand_color_question(design) if !confident_brand?(design)
            brand = design.brand
          end

          theme = target_theme
          palettes =
            ColorSchemes::Action::BuildFromBrand.call(
              brand:,
              accent: colors[:accent_color] || design&.accent,
              header: colors[:header_color] || design&.header,
            )
          site_settings = fonts.reverse_merge(website_fonts(design))

          draft = {
            kind: theme ? "palettes" : "theme",
            theme_id: theme&.id,
            name:,
            light_colors: palettes.light,
            dark_colors: palettes.dark,
            site_settings:,
          }.compact

          {
            status: "success",
            draft_token: AppearanceAuthoring::Draft.sign(draft, user: context.user),
            name: draft[:name],
            saves_as: saves_as(theme),
            colors: key_colors(palettes),
            readability_adjustments: palettes.adjustments.map { |adjustment| describe(adjustment) },
            fonts: site_settings.transform_values { |key| AppearanceAuthoring.font_name(key) },
            website: website_summary(design),
          }.compact_blank
        rescue Refusal => refusal
          error_response(refusal.message)
        end

        private

        def refuse(message)
          raise Refusal, message
        end

        def new_theme?
          ActiveModel::Type::Boolean.new.cast(parameters[:new_theme]) == true
        end

        def draft_name
          name = parameters[:name].to_s.squish.truncate(MAX_NAME_LENGTH, omission: "")
          name.presence || refuse(I18n.t("discourse_ai.appearance_authoring.name_required"))
        end

        def requested_colors
          values =
            COLOR_PARAMETERS
              .index_with { |name| parameters[name].to_s.strip.presence }
              .compact
              .transform_values { |value| [value, AppearanceAuthoring.parse_hex(value)] }

          invalid = values.values.filter_map { |value, hex| value if hex.nil? }
          if invalid.present?
            refuse(
              I18n.t("discourse_ai.appearance_authoring.invalid_color", colors: invalid.join(", ")),
            )
          end

          values.transform_values(&:last)
        end

        # Only exact matches, so a font Discourse doesn't offer is never
        # quietly swapped for another.
        def requested_fonts
          FONT_PARAMETERS.each_with_object({}) do |(parameter, setting_name), fonts|
            value = parameters[parameter].to_s.strip
            next if value.blank?

            key = AppearanceAuthoring.font_key(value)
            if key.nil?
              refuse(
                I18n.t(
                  "discourse_ai.appearance_authoring.unknown_font",
                  font: value,
                  fonts: DiscourseFonts.fonts.map { |font| font[:name] }.join(", "),
                ),
              )
            end
            fonts[setting_name] = key
          end
        end

        def website_design
          url = parameters[:website_url].to_s.strip
          return if url.blank?

          url = "https://#{url}" if !url.match?(%r{\A[a-z][a-z0-9+.-]*://}i)
          # only administrators get here, and staff skip rate limits by default
          RateLimiter.new(
            context.user,
            "admin-assistant-website-brand",
            WEBSITE_LOOKUPS_PER_HOUR,
            1.hour,
            apply_limit_to_staff: true,
          ).performed!

          AppearanceAuthoring::WebsiteDesign.read(
            url,
            llm: website_llm,
            user: context.user,
            feature_name: context.feature_name,
          ) || refuse(I18n.t("discourse_ai.appearance_authoring.website_unreadable", url:))
        rescue RateLimiter::LimitExceeded
          refuse(I18n.t("discourse_ai.appearance_authoring.website_rate_limited"))
        end

        # The model the assistant itself uses, or the site's default one.
        def website_llm
          return llm if llm

          model = LlmModel.find_by(id: SiteSetting.ai_default_llm_model.presence)
          DiscourseAi::Completions::Llm.proxy(model) if model
        end

        def confident_brand?(design)
          design&.brand.present? && design.confidence == :high
        end

        # Asks the administrator to pick a brand color when none was given, or
        # when the website doesn't point clearly at one.
        def brand_color_question(design)
          if design.nil?
            return error_response(I18n.t("discourse_ai.appearance_authoring.brand_color_required"))
          end

          domain = URI(design.url).host
          if design.candidates.empty?
            return(
              {
                status: "needs_brand_color",
                message: I18n.t("discourse_ai.appearance_authoring.no_brand_color_found", domain:),
              }
            )
          end

          {
            status: "needs_brand_color",
            message: I18n.t("discourse_ai.appearance_authoring.confirm_brand_color", domain:),
            candidates: design.candidates.map { |hex| "##{hex}" },
          }
        end

        # Fonts from the website, when Discourse offers them exactly.
        def website_fonts(design)
          return {} if design.nil?

          {
            "base_font" => design.body_font,
            "heading_font" => design.heading_font,
          }.filter_map { |setting_name, font| [setting_name, font.key] if font&.exact }.to_h
        end

        # New palettes go on the current default theme, unless the
        # administrator asked for a new theme.
        def target_theme
          guardian = context.user.guardian
          if !guardian.can_create_color_scheme?
            refuse(I18n.t("discourse_ai.appearance_authoring.palette_limit"))
          end
          return if new_theme?

          theme = Theme.find_default
          if theme.nil? || !guardian.can_edit_theme?(theme)
            refuse(I18n.t("discourse_ai.appearance_authoring.theme_not_editable"))
          end
          theme
        end

        def saves_as(theme)
          if theme
            return I18n.t("discourse_ai.appearance_authoring.palettes_target", theme: theme.name)
          end

          current = Theme.find_default
          if current.nil? || current.id == Theme::CORE_THEMES["foundation"]
            I18n.t("discourse_ai.appearance_authoring.new_theme_target")
          else
            I18n.t(
              "discourse_ai.appearance_authoring.new_theme_target_with_layout_change",
              theme: current.name,
            )
          end
        end

        def key_colors(palettes)
          AppearanceAuthoring::KEY_COLORS.to_h do |mode, name|
            palette = mode == "dark" ? palettes.dark : palettes.light
            [AppearanceAuthoring.color_label(mode, name), "##{palette[name]}"]
          end
        end

        def describe(adjustment)
          {
            color: AppearanceAuthoring.color_label(adjustment.mode, adjustment.name),
            from: "##{adjustment.from}",
            to: "##{adjustment.to}",
          }
        end

        # What came from the website, including the closest fonts it didn't
        # use because Discourse doesn't offer the website's own. Only the
        # domain is passed on: after redirects, the rest of the URL is up to
        # the website.
        def website_summary(design)
          return if design.nil?

          closest_fonts =
            { body: design.body_font, headings: design.heading_font }.filter_map do |role, font|
              [role, AppearanceAuthoring.font_name(font.key)] if font && !font.exact
            end

          {
            domain: URI(design.url).host,
            brand_color_confidence: design.confidence,
            dark_website: design.dark,
            closest_available_fonts: closest_fonts.to_h.presence,
          }.compact
        end
      end
    end
  end
end
