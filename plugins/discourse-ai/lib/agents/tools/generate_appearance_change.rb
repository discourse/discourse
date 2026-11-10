# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      # Builds readable light and dark palettes, and picks fonts, from brand
      # colors or from the administrator's own website, and styles for a new
      # theme from a description. Nothing changes on the site: the result is a
      # signed draft that save_appearance_change saves once an administrator
      # approves it.
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
                name: "styles",
                type: "string",
                description:
                  "Changes beyond colors and fonts, in the administrator's words, such as rounder corners, a shadow on topic rows, bigger topic titles or hiding the share button. They go in a new theme.",
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
            When an administrator asks to change the site's colors or fonts, or to match the look of their website, call generate_appearance_change. Pass website_url when they share a website. If it returns needs_brand_color, show the candidate colors and ask which one is their brand color, then call it again with brand_color and the same website_url. When it succeeds, say briefly what will change, including any colors adjusted so text stays readable, then call save_appearance_change with the exact draft token. When the result has a note, the site can't have new palettes, so it uses the closest palettes the site already has: pass the note on and name the palettes. If it returns no_change, tell the administrator nothing needs to change. Saving needs approval and doesn't change the site. Once it's saved, share the preview link and ask whether to make it live. Only call activate_appearance_change when the administrator asks to make it live; that needs approval too. To undo a change, find it with list_appearance_changes and call revert_appearance_change. Never say a change is live before activate_appearance_change succeeds. For other cosmetic changes, such as corners, shadows, borders, sizes, spacing or hiding minor elements, describe them in the styles parameter; they need a new theme. Pass the brand colors too when the administrator also wants new colors; otherwise the current colors are kept. Report the style_changes it returns, and anything under not_supported, which these tools can't do. Never write CSS yourself. A new theme starts from Foundation, core's default design, so warn a site using another theme that its layout will change.
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
              styles: style_request.present?,
            )
          return error_response(refusal) if refusal

          name = draft_name
          colors = requested_colors
          fonts = requested_fonts
          design = website_design

          brand = colors[:brand_color]
          if brand.nil? && !(style_request.present? && design.nil?)
            return brand_color_question(design) if !confident_brand?(design)
            brand = design.brand
          end

          theme = target_theme
          accent = colors[:accent_color] || design&.accent
          header = colors[:header_color] || design&.header
          site_settings = fonts.reverse_merge(website_fonts(design))

          reason = AppearanceAuthoring.palette_denial(user: context.user, phase: :generation)
          if theme && reason
            return(
              existing_palettes_draft(
                theme,
                reason:,
                brand:,
                accent:,
                header:,
                site_settings:,
                design:,
              )
            )
          end

          palettes =
            if brand
              ColorSchemes::Action::BuildFromBrand.call(brand:, accent:, header:)
            else
              current_palettes
            end
          authored = authored_styles(light: palettes.light, dark: palettes.dark)
          edited = edited_change if authored
          styles =
            theme_styles(
              authored,
              website: (website_styles(design) if theme.nil?),
              palettes: {
                light: palettes.light,
                dark: palettes.dark,
              },
            )
          draft = {
            kind: theme ? "palettes" : "theme",
            theme_id: theme&.id,
            replaces_theme_id: edited&.theme_id,
            name: edited&.name || name,
            light_colors: palettes.light,
            dark_colors: palettes.dark,
            site_settings:,
            styles: styles&.styles,
          }.compact

          {
            status: "success",
            draft_token: AppearanceAuthoring::Draft.sign(draft, user: context.user),
            name: draft[:name],
            saves_as: edited ? new_version_target(edited) : saves_as(theme),
            colors: key_colors(light: palettes.light, dark: palettes.dark),
            readability_adjustments: palettes.adjustments.map { |adjustment| describe(adjustment) },
            fonts: site_settings.transform_values { |key| AppearanceAuthoring.font_name(key) },
            style_changes: styles&.changes&.map { |change| "#{change.label}: #{change.value}" },
            not_supported: authored&.unsupported,
            website: website_summary(design),
          }.compact_blank
        rescue Refusal => refusal
          error_response(refusal.message)
        end

        private

        def refuse(message)
          raise Refusal, message
        end

        # Styles only go in a theme of their own.
        def new_theme?
          ActiveModel::Type::Boolean.new.cast(parameters[:new_theme]) == true ||
            style_request.present?
        end

        def style_request
          parameters[:styles].to_s.strip
        end

        # Styles from the administrator's description, checked against the
        # palettes they'll be shown with.
        def authored_styles(light:, dark:)
          return if style_request.blank?

          llm = website_llm
          refuse(I18n.t("discourse_ai.appearance_authoring.styles_failed")) if llm.nil?

          result =
            AppearanceAuthoring::StyleAuthor.new(
              llm:,
              user: context.user,
              feature_name: context.feature_name,
            ).call(
              style_request,
              palettes: {
                light:,
                dark:,
              },
              current_styles: edited_change&.styles,
            )
          if result.is_a?(AppearanceAuthoring::StyleAuthor::Failure)
            refuse(I18n.t("discourse_ai.appearance_authoring.styles_failed"))
          end
          if result.styles.blank?
            refuse(
              I18n.t(
                "discourse_ai.appearance_authoring.styles_unsupported",
                requests: result.unsupported.join("; "),
              ),
            )
          end
          result
        end

        # The change that made the live theme, when the assistant still
        # manages that theme, so styles become a new version of it rather
        # than a separate theme.
        def edited_change
          return @edited_change if defined?(@edited_change)

          current = Theme.find_default
          @edited_change =
            if !ActiveModel::Type::Boolean.new.cast(parameters[:new_theme]) &&
                 AppearanceChange.replaceable?(current) &&
                 context.user.guardian.can_edit_theme?(current)
              AppearanceChange.kind_theme.where(theme_id: current.id).order(:id).last
            end
        end

        def new_version_target(appearance_change)
          I18n.t(
            "discourse_ai.appearance_authoring.new_version_target",
            name: appearance_change.name,
          )
        end

        Styles = Data.define(:styles, :changes)

        # The draft's styles: the ones written for the administrator's
        # request, plus the website's button shape unless they set it
        # themselves. Checked again as a whole; without the website's part
        # when that doesn't pass.
        def theme_styles(authored, website:, palettes:)
          if website.nil?
            return authored && Styles.new(styles: authored.styles, changes: authored.changes)
          end

          combined = (authored&.styles || {}).deep_dup
          combined["variables"] = website["variables"].merge(combined["variables"] || {})
          result = AppearanceStyles::Policy.call(combined, palettes:)
          if result.valid?
            Styles.new(styles: combined, changes: result.changes)
          elsif authored
            Styles.new(styles: authored.styles, changes: authored.changes)
          end
        end

        # The website's button shape, when a new theme with styles is allowed.
        def website_styles(design)
          radius = design&.button_radius
          return if radius.nil?
          return if AppearanceAuthoring.denial(user: context.user, phase: :generation, styles: true)

          value =
            if radius >= AppearanceAuthoring::WebsiteDesign::PILL_RADIUS
              "var(--d-border-radius-pill)"
            else
              "#{radius.clamp(0, 32)}px"
            end
          { "variables" => { "--d-button-border-radius" => value } }
        end

        # A new theme for styles alone keeps the colors the site shows now.
        def current_palettes
          current = AppearanceAuthoring.theme_palettes(Theme.find_default)
          ColorSchemes::Action::BuildFromBrand::Result.new(
            light: AppearanceAuthoring.complete_palette(current[:light]),
            dark:
              AppearanceAuthoring.complete_palette(
                current[:dark] || ColorScheme::BUILT_IN_SCHEMES[:Dark],
              ),
            adjustments: [],
          )
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

        # Palettes go on the current default theme, unless the administrator
        # asked for a new theme.
        def target_theme
          return if new_theme?

          theme = Theme.find_default
          if theme.nil? || !context.user.guardian.can_edit_theme?(theme)
            refuse(I18n.t("discourse_ai.appearance_authoring.theme_not_editable"))
          end
          theme
        end

        # Without new palettes, uses the closest of the ones the theme can
        # already use. `reason` says why there are no new palettes.
        def existing_palettes_draft(
          theme,
          reason:,
          brand:,
          accent:,
          header:,
          site_settings:,
          design:
        )
          choice = AppearanceAuthoring::PaletteChoice.closest(theme:, brand:, accent:, header:)
          refuse(reason) if choice.nil?

          # the closest palettes may be the theme's already, while the fonts still change
          if same_palettes?(theme, choice) && AppearanceAuthoring.font_changes(site_settings).empty?
            return(
              {
                status: "no_change",
                message:
                  I18n.t(
                    "discourse_ai.appearance_authoring.already_closest",
                    palette: choice.name,
                    theme: theme.name,
                  ),
                note: reason,
              }
            )
          end

          draft = {
            kind: "existing_palettes",
            theme_id: theme.id,
            name: choice.name,
            light_palette_id: choice.light_palette_id,
            dark_palette_id: choice.dark_palette_id,
            light_colors: choice.light_colors,
            dark_colors: choice.dark_colors,
            site_settings:,
          }

          {
            status: "success",
            draft_token: AppearanceAuthoring::Draft.sign(draft, user: context.user),
            name: choice.name,
            saves_as:
              I18n.t(
                "discourse_ai.appearance_authoring.existing_palettes_target",
                palette: choice.name,
                theme: theme.name,
              ),
            note: reason,
            colors: key_colors(light: choice.light_colors, dark: choice.dark_colors),
            fonts: site_settings.transform_values { |key| AppearanceAuthoring.font_name(key) },
            website: website_summary(design),
          }.compact_blank
        end

        # Hover and selected colors are derived from the others when a palette
        # doesn't set them, so they don't tell palettes apart.
        def same_palettes?(theme, choice)
          compared = ColorScheme.base_colors.keys - %w[hover selected]
          current = AppearanceAuthoring.theme_palettes(theme)

          [
            [current[:light], choice.light_colors],
            [current[:dark], choice.dark_colors],
          ].all? do |colors, chosen|
            colors.present? && colors.slice(*compared) == chosen.slice(*compared)
          end
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

        def key_colors(light:, dark:)
          AppearanceAuthoring::KEY_COLORS.to_h do |mode, name|
            palette = mode == "dark" ? dark : light
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
            button_radius: design.button_radius && "#{design.button_radius}px",
            closest_available_fonts: closest_fonts.to_h.presence,
          }.compact
        end
      end
    end
  end
end
