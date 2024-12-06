# frozen_string_literal: true

class Wizard
  class Builder
    def initialize(user)
      @wizard = Wizard.new(user)
    end

    def build
      return @wizard unless SiteSetting.wizard_enabled? && @wizard.user.try(:staff?)

      append_introduction_step
      append_privacy_step
      append_styling_step
      append_ready_step
      append_branding_step
      append_corporate_step

      DiscourseEvent.trigger(:build_wizard, @wizard)
      @wizard
    end

    protected

    def append_introduction_step
      @wizard.append_step("introduction") do |step|
        step.emoji = "wave"
        step.description_vars = { base_path: Discourse.base_path }

        step.add_field(
          id: "title",
          type: "text",
          required: true,
          value: SiteSetting.title == SiteSetting.defaults[:title] ? "" : SiteSetting.title,
        )
        step.add_field(
          id: "site_description",
          type: "text",
          required: false,
          value: SiteSetting.site_description,
        )

        languages =
          step.add_field(
            id: "default_locale",
            type: "dropdown",
            required: false,
            value: SiteSetting.default_locale,
          )

        LocaleSiteSetting.values.each do |locale|
          languages.add_choice(locale[:value], label: locale[:name])
        end

        step.on_update do |updater|
          updater.ensure_changed(:title)

          updater.apply_settings(:title, :site_description) if updater.errors.blank?

          old_locale = SiteSetting.default_locale
          updater.apply_setting(:default_locale)

          if old_locale != updater.fields[:default_locale]
            Scheduler::Defer.later "Reseed" do
              SeedData::Categories.with_default_locale.update(skip_changed: true)
              SeedData::Topics.with_default_locale.update(skip_changed: true)
            end

            updater.refresh_required = true
          end
        end
      end
    end

    def append_privacy_step
      @wizard.append_step("privacy") do |step|
        step.emoji = "hugs"

        step.add_field(
          id: "login_required",
          type: "radio",
          value: SiteSetting.login_required ? "private" : "public",
        ) do |field|
          field.add_choice("public")
          field.add_choice("private")
        end

        step.add_field(
          id: "invite_only",
          type: "radio",
          value: SiteSetting.invite_only ? "invite_only" : "sign_up",
        ) do |field|
          field.add_choice("sign_up", icon: "user-plus")
          field.add_choice("invite_only", icon: "paper-plane")
        end

        step.add_field(
          id: "must_approve_users",
          type: "radio",
          value: SiteSetting.must_approve_users ? "yes" : "no",
        ) do |field|
          field.add_choice("no")
          field.add_choice("yes")
        end

        step.on_update do |updater|
          updater.update_setting(:login_required, updater.fields[:login_required] == "private")
          updater.update_setting(:invite_only, updater.fields[:invite_only] == "invite_only")
          updater.update_setting(:must_approve_users, updater.fields[:must_approve_users] == "yes")
        end
      end
    end

    def append_ready_step
      @wizard.append_step("ready") do |step|
        # no form on this page, just info.
        step.emoji = "rocket"
      end
    end

    def append_branding_step
      @wizard.append_step("branding") do |step|
        step.emoji = "framed_picture"
        step.add_field(id: "logo", type: "image", value: SiteSetting.site_logo_url)
        step.add_field(id: "logo_small", type: "image", value: SiteSetting.site_logo_small_url)

        step.on_update do |updater|
          if SiteSetting.site_logo_url != updater.fields[:logo] ||
               SiteSetting.site_logo_small_url != updater.fields[:logo_small]
            updater.apply_settings(:logo, :logo_small)
            updater.refresh_required = true
          end
        end
      end
    end

    def append_styling_step
      @wizard.append_step("styling") do |step|
        step.emoji = "art"
        default_theme = Theme.find_by(id: SiteSetting.default_theme_id)
        default_theme_override = SiteSetting.exists?(name: "default_theme_id")

        base_scheme = default_theme&.color_scheme&.base_scheme_id
        color_scheme_name = default_theme&.color_scheme&.name

        scheme_id =
          default_theme_override ? (base_scheme || color_scheme_name) : ColorScheme::LIGHT_THEME_ID

        themes =
          step.add_field(
            id: "color_scheme",
            type: "dropdown",
            required: !default_theme_override,
            value: scheme_id || ColorScheme::LIGHT_THEME_ID,
            show_in_sidebar: true,
          )

        # fix for the case when base_scheme is nil
        if scheme_id && default_theme_override && base_scheme.nil?
          scheme = default_theme.color_scheme
          themes.add_choice(scheme_id, data: { colors: scheme.colors_hashes })
        end

        ColorScheme.base_color_scheme_colors.each do |t|
          themes.add_choice(t[:id], data: { colors: t[:colors] })
        end

        body_font =
          step.add_field(
            id: "body_font",
            type: "dropdown",
            value: SiteSetting.base_font,
            show_in_sidebar: true,
          )

        heading_font =
          step.add_field(
            id: "heading_font",
            type: "dropdown",
            value: SiteSetting.heading_font,
            show_in_sidebar: true,
          )

        DiscourseFonts
          .fonts
          .sort_by { |f| f[:name] }
          .each do |font|
            body_font.add_choice(font[:key], label: font[:name])
            heading_font.add_choice(font[:key], label: font[:name])
          end

        current =
          (
            if SiteSetting.top_menu_map.first == "categories"
              SiteSetting.desktop_category_page_style
            else
              "latest"
            end
          )
        style =
          step.add_field(
            id: "homepage_style",
            type: "dropdown",
            required: false,
            value: current,
            show_in_sidebar: true,
          )
        style.add_choice("latest")
        CategoryPageStyle.values.each { |page| style.add_choice(page[:value]) }

        step.add_field(id: "styling_preview", type: "styling-preview")

        step.on_update do |updater|
          updater.update_setting(:base_font, updater.fields[:body_font])
          updater.update_setting(:heading_font, updater.fields[:heading_font])

          top_menu = SiteSetting.top_menu_map
          if updater.fields[:homepage_style] == "latest" && top_menu.first != "latest"
            top_menu.delete("latest")
            top_menu.insert(0, "latest")
          elsif updater.fields[:homepage_style] != "latest"
            top_menu.delete("categories")
            top_menu.insert(0, "categories")
            updater.update_setting(:desktop_category_page_style, updater.fields[:homepage_style])
          end
          updater.update_setting(:top_menu, top_menu.join("|"))

          scheme_name = ((updater.fields[:color_scheme] || "") || ColorScheme::LIGHT_THEME_ID)

          next unless scheme_name.present? && ColorScheme.is_base?(scheme_name)

          name = I18n.t("color_schemes.#{scheme_name.downcase.gsub(" ", "_")}_theme_name")

          scheme = ColorScheme.find_by(base_scheme_id: scheme_name, via_wizard: true)
          scheme ||=
            ColorScheme.create_from_base(name: name, via_wizard: true, base_scheme_id: scheme_name)

          if default_theme
            default_theme.color_scheme_id = scheme.id
            default_theme.save!
          else
            theme =
              Theme.create!(
                name: I18n.t("color_schemes.default_theme_name"),
                user_id: @wizard.user.id,
                color_scheme_id: scheme.id,
              )

            theme.set_default!
          end

          updater.update_setting(:default_dark_mode_color_scheme_id, -1) if scheme.is_dark?
          updater.refresh_required = true
        end
      end
    end

    def append_corporate_step
      @wizard.append_step("corporate") do |step|
        step.emoji = "briefcase"
        step.description_vars = { base_path: Discourse.base_path }
        step.add_field(id: "company_name", type: "text", value: SiteSetting.company_name)
        step.add_field(id: "governing_law", type: "text", value: SiteSetting.governing_law)
        step.add_field(id: "contact_url", type: "text", value: SiteSetting.contact_url)
        step.add_field(id: "city_for_disputes", type: "text", value: SiteSetting.city_for_disputes)
        step.add_field(id: "contact_email", type: "text", value: SiteSetting.contact_email)

        step.on_update do |updater|
          update_tos do |raw|
            replace_setting_value(updater, raw, "company_name")
            replace_setting_value(updater, raw, "governing_law")
            replace_setting_value(updater, raw, "city_for_disputes")
          end

          if updater.errors.blank?
            updater.apply_settings(
              :company_name,
              :governing_law,
              :city_for_disputes,
              :contact_url,
              :contact_email,
            )
          end
        end
      end
    end

    def replace_setting_value(updater, raw, field_name)
      old_value = SiteSetting.get(field_name)
      old_value = field_name if old_value.blank?

      new_value = updater.fields[field_name.to_sym]
      new_value = field_name if new_value.blank?

      raw.gsub!("<ins>#{old_value}</ins>", new_value) || raw.gsub!(old_value, new_value)
    end

    def reserved_usernames
      @reserved_usernames ||= SiteSetting.defaults[:reserved_usernames].split("|")
    end

    def update_tos
      tos_post = Post.find_by(topic_id: SiteSetting.tos_topic_id, post_number: 1)

      if tos_post.present?
        raw = tos_post.raw.dup

        yield(raw)

        revisor = PostRevisor.new(tos_post)
        revisor.revise!(@wizard.user, raw: raw)
      end
    end
  end
end
