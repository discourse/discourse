# frozen_string_literal: true

class Wizard
  class Builder

    def initialize(user)
      @wizard = Wizard.new(user)
    end

    def build
      return @wizard unless SiteSetting.wizard_enabled? && @wizard.user.try(:staff?)

      @wizard.append_step('locale') do |step|
        step.banner = "welcome.png"

        languages = step.add_field(id: 'default_locale',
                                   type: 'dropdown',
                                   required: true,
                                   value: SiteSetting.default_locale)

        LocaleSiteSetting.values.each do |locale|
          languages.add_choice(locale[:value], label: locale[:name])
        end

        step.on_update do |updater|
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

      @wizard.append_step('forum-title') do |step|
        step.add_field(id: 'title', type: 'text', required: true, value: SiteSetting.title)
        step.add_field(id: 'site_description', type: 'text', required: true, value: SiteSetting.site_description)
        step.add_field(id: 'short_site_description', type: 'text', required: false, value: SiteSetting.short_site_description)

        step.on_update do |updater|
          updater.ensure_changed(:title)

          if updater.errors.blank?
            updater.apply_settings(:title, :site_description, :short_site_description)
          end
        end
      end

      @wizard.append_step('introduction') do |step|
        introduction = IntroductionUpdater.new(@wizard.user)

        if @wizard.completed_steps?('introduction') && !introduction.get_summary
          step.disabled = true
          step.description_vars = { topic_title: I18n.t("discourse_welcome_topic.title") }
        else
          step.add_field(id: 'welcome', type: 'textarea', required: true, value: introduction.get_summary)

          step.on_update do |updater|
            value = updater.fields[:welcome].strip

            if value.index("\n")
              updater.errors.add(:welcome, I18n.t("wizard.step.introduction.fields.welcome.one_paragraph"))
            else
              introduction.update_summary(value)
            end
          end
        end
      end

      @wizard.append_step('privacy') do |step|
        privacy = step.add_field(id: 'privacy',
                                 type: 'radio',
                                 required: true,
                                 value: SiteSetting.login_required? ? 'restricted' : 'open')
        privacy.add_choice('open', icon: 'unlock')
        privacy.add_choice('restricted', icon: 'lock')

        unless SiteSetting.invite_only? && SiteSetting.must_approve_users?
          privacy_option_value = "open"
          privacy_option_value = "invite_only" if SiteSetting.invite_only?
          privacy_option_value = "must_approve" if SiteSetting.must_approve_users?
          privacy_options = step.add_field(id: 'privacy_options',
                                           type: 'radio',
                                           required: true,
                                           value: privacy_option_value)
          privacy_options.add_choice('open')
          privacy_options.add_choice('invite_only')
          privacy_options.add_choice('must_approve')
        end

        step.on_update do |updater|
          updater.update_setting(:login_required, updater.fields[:privacy] == 'restricted')
          unless SiteSetting.invite_only? && SiteSetting.must_approve_users?
            updater.update_setting(:invite_only, updater.fields[:privacy_options] == "invite_only")
            updater.update_setting(:must_approve_users, updater.fields[:privacy_options] == "must_approve")
          end
        end
      end

      @wizard.append_step('contact') do |step|
        step.add_field(id: 'contact_email', type: 'text', required: true, value: SiteSetting.contact_email)
        step.add_field(id: 'contact_url', type: 'text', value: SiteSetting.contact_url)

        username = SiteSetting.site_contact_username
        username = Discourse.system_user.username if username.blank?
        contact = step.add_field(id: 'site_contact', type: 'dropdown', value: username)

        User.human_users.where(admin: true).pluck(:username).each do |c|
          contact.add_choice(c) unless reserved_usernames.include?(c.downcase)
        end
        contact.add_choice(Discourse.system_user.username)

        step.on_update do |updater|
          update_tos do |raw|
            replace_setting_value(updater, raw, 'contact_email')
          end

          updater.apply_settings(:contact_email, :contact_url)
          updater.update_setting(:site_contact_username, updater.fields[:site_contact])
        end
      end

      @wizard.append_step('corporate') do |step|
        step.description_vars = { base_path: Discourse.base_path }
        step.add_field(id: 'company_name', type: 'text', value: SiteSetting.company_name)
        step.add_field(id: 'governing_law', type: 'text', value: SiteSetting.governing_law)
        step.add_field(id: 'city_for_disputes', type: 'text', value: SiteSetting.city_for_disputes)

        step.on_update do |updater|
          update_tos do |raw|
            replace_setting_value(updater, raw, 'company_name')
            replace_setting_value(updater, raw, 'governing_law')
            replace_setting_value(updater, raw, 'city_for_disputes')
          end

          updater.apply_settings(:company_name, :governing_law, :city_for_disputes)
        end
      end

      @wizard.append_step('colors') do |step|
        default_theme = Theme.find_by(id: SiteSetting.default_theme_id)
        default_theme_override = SiteSetting.exists?(name: "default_theme_id")

        base_scheme = default_theme&.color_scheme&.base_scheme_id
        color_scheme_name = default_theme&.color_scheme&.name

        scheme_id = default_theme_override ? (base_scheme || color_scheme_name) : ColorScheme::LIGHT_THEME_ID

        themes = step.add_field(
          id: 'theme_previews',
          type: 'component',
          required: !default_theme_override,
          value: scheme_id
        )

        # fix for the case when base_scheme is nil
        if scheme_id && default_theme_override && base_scheme.nil?
          scheme = default_theme.color_scheme
          default_colors = scheme.colors.select(:name, :hex)
          choice_hash = default_colors.reduce({}) { |choice, color| choice[color.name] = "##{color.hex}"; choice }
          themes.add_choice(scheme_id, data: { colors: choice_hash })
        end

        ColorScheme.base_color_scheme_colors.each do |t|
          with_hash = t[:colors].dup
          with_hash.map { |k, v| with_hash[k] = "##{v}" }
          themes.add_choice(t[:id], data: { colors: with_hash })
        end

        step.on_update do |updater|
          scheme_name = (
            (updater.fields[:theme_previews] || "") ||
            ColorScheme::LIGHT_THEME_ID
          )

          next unless scheme_name.present? && ColorScheme.is_base?(scheme_name)

          name = I18n.t("color_schemes.#{scheme_name.downcase.gsub(' ', '_')}_theme_name")

          theme = nil
          scheme = ColorScheme.find_by(base_scheme_id: scheme_name, via_wizard: true)
          scheme ||= ColorScheme.create_from_base(name: name, via_wizard: true, base_scheme_id: scheme_name)
          themes = Theme.where(color_scheme_id: scheme.id).order(:id).to_a
          theme = themes.find(&:default?)
          theme ||= themes.first

          theme ||= Theme.create!(
            name: name,
            user_id: @wizard.user.id,
            color_scheme_id: scheme.id
          )

          theme.set_default!
        end
      end

      @wizard.append_step('themes-further-reading') do |step|
        step.banner = "further-reading.png"
        step.add_field(id: 'popular-themes', type: 'component')
      end

      @wizard.append_step('logos') do |step|
        step.add_field(id: 'logo', type: 'image', value: SiteSetting.site_logo_url)
        step.add_field(id: 'logo_small', type: 'image', value: SiteSetting.site_logo_small_url)

        step.on_update do |updater|
          if SiteSetting.site_logo_url != updater.fields[:logo] ||
            SiteSetting.site_logo_small_url != updater.fields[:logo_small]
            updater.apply_settings(:logo, :logo_small)
            updater.refresh_required = true
          end
        end
      end

      @wizard.append_step('icons') do |step|
        step.add_field(id: 'favicon', type: 'image', value: SiteSetting.site_favicon_url)
        step.add_field(id: 'large_icon', type: 'image', value: SiteSetting.site_large_icon_url)

        step.on_update do |updater|
          updater.apply_settings(:favicon) if SiteSetting.site_favicon_url != updater.fields[:favicon]
          updater.apply_settings(:large_icon) if SiteSetting.site_large_icon_url != updater.fields[:large_icon]
        end
      end

      @wizard.append_step('homepage') do |step|

        current = SiteSetting.top_menu.starts_with?("categories") ? SiteSetting.desktop_category_page_style : "latest"

        style = step.add_field(id: 'homepage_style', type: 'dropdown', required: true, value: current)
        style.add_choice('latest')
        CategoryPageStyle.values.each do |page|
          style.add_choice(page[:value])
        end

        step.add_field(id: 'homepage_preview', type: 'component')

        step.on_update do |updater|
          if updater.fields[:homepage_style] == 'latest'
            top_menu = "latest|new|unread|top|categories"
          else
            top_menu = "categories|latest|new|unread|top"
            updater.update_setting(:desktop_category_page_style, updater.fields[:homepage_style])
          end
          updater.update_setting(:top_menu, top_menu)
        end
      end

      @wizard.append_step('emoji') do |step|
        sets = step.add_field(id: 'emoji_set',
                              type: 'radio',
                              required: true,
                              value: SiteSetting.emoji_set)

        emoji = ["smile", "+1", "tada", "poop"]

        EmojiSetSiteSetting.values.each do |set|
          imgs = emoji.map do |e|
            "<img src='#{Discourse.base_uri}/images/emoji/#{set[:value]}/#{e}.png'>"
          end

          sets.add_choice(set[:value],
                          label: I18n.t("js.#{set[:name]}"),
                          extra_label: "<span class='emoji-preview'>#{imgs.join}</span>")

          step.on_update do |updater|
            updater.apply_settings(:emoji_set)
          end
        end
      end

      @wizard.append_step('invites') do |step|
        if SiteSetting.enable_local_logins
          staff_count = User.staff.human_users.where('username_lower not in (?)', reserved_usernames).count
          step.add_field(id: 'staff_count', type: 'component', value: staff_count)

          step.add_field(id: 'invite_list', type: 'component')

          step.on_update do |updater|
            users = JSON.parse(updater.fields[:invite_list])

            users.each do |u|
              args = {}
              args[:moderator] = true if u['role'] == 'moderator'
              begin
                Invite.create_invite_by_email(u['email'], @wizard.user, args)
              rescue => e
                updater.errors.add(:invite_list, e.message.concat("<br>"))
              end
            end
          end
        else
          step.disabled = true
        end
      end

      DiscourseEvent.trigger(:build_wizard, @wizard)

      @wizard.append_step('finished') do |step|
        step.banner = "finished.png"
        step.description_vars = { base_path: Discourse.base_path }
      end
      @wizard
    end

    protected

    def replace_setting_value(updater, raw, field_name)
      old_value = SiteSetting.get(field_name)
      old_value = field_name if old_value.blank?

      new_value = updater.fields[field_name.to_sym]
      new_value = field_name if new_value.blank?

      raw.gsub!("<ins>#{old_value}</ins>", new_value) || raw.gsub!(old_value, new_value)
    end

    def reserved_usernames
      @reserved_usernames ||= SiteSetting.defaults[:reserved_usernames].split('|')
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
