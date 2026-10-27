# frozen_string_literal: true

module DiscourseAi
  module Agents
    # What the Admin Assistant's appearance tools share: who can use them, the
    # drafts they sign, and how they describe palettes on approval cards.
    module AppearanceAuthoring
      # Changing colors and fonts, and creating a new theme, are checked as
      # separate features.
      FEATURE = :appearance_authoring
      THEME_FEATURE = :theme_authoring

      # The colors approval cards compare, as [palette, color name].
      KEY_COLORS = [
        %w[light tertiary],
        %w[light header_background],
        %w[light quaternary],
        %w[dark tertiary],
      ].freeze
      HEX_COLOR = /\A\h{6}\z/
      HEX_INPUT = /\A#?(\h{3}|\h{6})\z/

      # A palette or theme generated for an administrator, waiting to be saved.
      class Draft < Tools::DraftReference
        class << self
          private

          def draft_kind
            "appearance"
          end
        end
      end

      def self.visible?(user)
        !!user&.admin? && access(user:, phase: :visibility).allowed
      end

      # Returns why the user can't change the site's appearance, or nil when
      # they can.
      def self.denial(user:, phase:, new_theme: false)
        return I18n.t("discourse_ai.appearance_authoring.not_allowed") if !user&.admin?

        access = access(user:, phase:)
        if !access.allowed
          return access.message.presence || I18n.t("discourse_ai.appearance_authoring.unavailable")
        end

        theme_denial(user:, phase:) if new_theme
      end

      def self.theme_denial(user:, phase:)
        access = access(user:, phase:, feature: THEME_FEATURE)
        if !access.allowed
          return(
            access.message.presence ||
              I18n.t("discourse_ai.appearance_authoring.themes_unavailable")
          )
        end

        # sites that only allow themes from approved repositories can't add local ones
        if !user.guardian.can_create_theme? || !Theme.allowed_remote_theme_ids.nil?
          I18n.t("discourse_ai.appearance_authoring.themes_unavailable")
        end
      end
      private_class_method :theme_denial

      def self.access(user:, phase:, feature: FEATURE)
        AdminAssistantAccess.check(feature:, user:, phase:)
      end
      private_class_method :access

      # A theme's light and dark palettes as { "color name" => "hex" }. A theme
      # without a light palette uses core's colors, and one without a dark
      # palette has no dark mode.
      def self.theme_palettes(theme)
        {
          light: palette_colors(theme&.color_scheme) || normalize_colors(ColorScheme.base_colors),
          dark: palette_colors(theme&.dark_color_scheme),
        }
      end

      def self.change_palettes(appearance_change)
        {
          light: palette_colors(appearance_change.light_color_scheme),
          dark: palette_colors(appearance_change.dark_color_scheme),
        }
      end

      def self.palette_colors(color_scheme)
        normalize_colors(color_scheme.resolved_colors) if color_scheme
      end

      # Approval card rows for the key colors that differ between two sets of
      # palettes.
      def self.color_changes(before:, after:)
        KEY_COLORS.filter_map do |mode, name|
          from = before[mode.to_sym]&.[](name)
          to = after[mode.to_sym]&.[](name)
          next if !to.to_s.match?(HEX_COLOR) || from == to

          {
            label: color_label(mode, name),
            before: from ? "##{from}" : empty_value,
            after: "##{to}",
            before_color: (from if from.to_s.match?(HEX_COLOR)),
            after_color: to,
          }.compact
        end
      end

      # Approval card rows for the fonts that would change.
      def self.font_changes(site_settings)
        site_settings
          .to_h
          .slice(*AppearanceChange::SITE_SETTING_NAMES)
          .filter_map do |setting_name, key|
            current = SiteSetting.get(setting_name)
            next if key.blank? || current == key

            {
              label: I18n.t("discourse_ai.appearance_authoring.fonts.#{setting_name}"),
              before: font_name(current),
              after: font_name(key),
            }
          end
      end

      def self.default_theme_change(from:, to:)
        {
          label: I18n.t("discourse_ai.appearance_authoring.default_theme"),
          before: from&.name || empty_value,
          after: to&.name || empty_value,
        }
      end

      def self.color_label(mode, name)
        I18n.t("discourse_ai.appearance_authoring.colors.#{mode}.#{name}", default: name.to_s)
      end

      def self.font_name(key)
        DiscourseFonts.fonts.find { |font| font[:key] == key }&.dig(:name) || key.to_s
      end

      # The key of the Discourse font a name or key refers to, such as "lora"
      # for "Lora", or nil when Discourse doesn't offer that font.
      def self.font_key(name)
        normalized = normalize_font_name(name)
        return if normalized.blank?

        DiscourseFonts
          .fonts
          .find do |font|
            [font[:key], font[:name]].any? { |value| normalize_font_name(value) == normalized }
          end
          &.dig(:key)
      end

      # Six-digit lowercase hex for a hex color such as "#635BFF" or "fa0", or
      # nil for anything else.
      def self.parse_hex(value)
        digits = value.to_s.strip[HEX_INPUT, 1]
        return if digits.nil?

        digits = digits.chars.map { |digit| digit * 2 }.join if digits.length == 3
        digits.downcase
      end

      # Lets staff see a saved change before it goes live: a new theme through
      # theme preview, new palettes on top of the current theme.
      def self.preview_url(appearance_change)
        query =
          if appearance_change.kind_theme?
            { preview_theme_id: appearance_change.theme_id }
          else
            {
              preview_color_scheme_id: appearance_change.light_color_scheme_id,
              preview_dark_color_scheme_id: appearance_change.dark_color_scheme_id,
            }
          end
        "#{Discourse.base_url}/?#{query.to_query}"
      end

      def self.safe_mode_url
        "#{Discourse.base_url}/?safe_mode=no_themes"
      end

      def self.status(appearance_change)
        if appearance_change.applied?
          "live"
        elsif appearance_change.draft?
          "draft"
        else
          "not_live"
        end
      end

      def self.normalize_colors(colors)
        colors.to_h.transform_values do |hex|
          hex = hex.to_s.downcase
          hex.length == 3 ? hex.gsub(/(\h)/, '\1\1') : hex
        end
      end
      private_class_method :normalize_colors

      def self.empty_value
        I18n.t("discourse_ai.ai_bot.chat_tool_approval.empty_value")
      end
      private_class_method :empty_value

      def self.normalize_font_name(name)
        name.to_s.downcase.gsub(/[^a-z0-9]/, "")
      end
      private_class_method :normalize_font_name
    end
  end
end
