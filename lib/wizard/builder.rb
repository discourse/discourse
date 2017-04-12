require_dependency 'introduction_updater'
require_dependency 'emoji_set_site_setting'

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
          updater.refresh_required = true if old_locale != updater.fields[:default_locale]
        end
      end

      @wizard.append_step('forum-title') do |step|
        step.add_field(id: 'title', type: 'text', required: true, value: SiteSetting.title)
        step.add_field(id: 'site_description', type: 'text', required: true, value: SiteSetting.site_description)

        step.on_update do |updater|
          updater.ensure_changed(:title)

          if updater.errors.blank?
            updater.apply_settings(:title, :site_description)
          end
        end
      end

      @wizard.append_step('introduction') do |step|
        introduction = IntroductionUpdater.new(@wizard.user)

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

      @wizard.append_step('privacy') do |step|
        locked = SiteSetting.login_required? && SiteSetting.invite_only?
        privacy = step.add_field(id: 'privacy',
                                 type: 'radio',
                                 required: true,
                                 value: locked ? 'restricted' : 'open')
        privacy.add_choice('open', icon: 'unlock')
        privacy.add_choice('restricted', icon: 'lock')

        step.on_update do |updater|
          updater.update_setting(:login_required, updater.fields[:privacy] == 'restricted')
          updater.update_setting(:invite_only, updater.fields[:privacy] == 'restricted')
        end
      end

      @wizard.append_step('contact') do |step|
        step.add_field(id: 'contact_email', type: 'text', required: true, value: SiteSetting.contact_email)
        step.add_field(id: 'contact_url', type: 'text', value: SiteSetting.contact_url)

        username = SiteSetting.site_contact_username
        username = Discourse.system_user.username if username.blank?
        contact = step.add_field(id: 'site_contact', type: 'dropdown', value: username)

        User.where(admin: true).pluck(:username).each {|c| contact.add_choice(c) }

        step.on_update do |updater|
          updater.apply_settings(:contact_email, :contact_url)
          updater.update_setting(:site_contact_username, updater.fields[:site_contact])
        end
      end

      @wizard.append_step('corporate') do |step|
        step.add_field(id: 'company_short_name', type: 'text', value: SiteSetting.company_short_name)
        step.add_field(id: 'company_full_name', type: 'text', value: SiteSetting.company_full_name)
        step.add_field(id: 'company_domain', type: 'text', value: SiteSetting.company_domain)

        step.on_update do |updater|

          tos_post = Post.where(topic_id: SiteSetting.tos_topic_id, post_number: 1).first
          if tos_post.present?
            raw = tos_post.raw.dup

            replace_company(updater, raw, 'company_full_name')
            replace_company(updater, raw, 'company_short_name')
            replace_company(updater, raw, 'company_domain')

            revisor = PostRevisor.new(tos_post)
            revisor.revise!(@wizard.user, raw: raw)
          end

          updater.apply_settings(:company_short_name, :company_full_name, :company_domain)
        end
      end

      @wizard.append_step('colors') do |step|
        scheme_id = ColorScheme.where(via_wizard: true).pluck(:base_scheme_id)&.first
        scheme_id ||= 'default'

        themes = step.add_field(id: 'base_scheme_id', type: 'dropdown', required: true, value: scheme_id)
        ColorScheme.base_color_scheme_colors.each do |t|
          with_hash = t[:colors].dup
          with_hash.map{|k,v| with_hash[k] = "##{v}"}
          themes.add_choice(t[:id], data: {colors: with_hash})
        end
        step.add_field(id: 'theme_preview', type: 'component')

        step.on_update do |updater|
          scheme_name = updater.fields[:base_scheme_id]

          theme = ColorScheme.base_color_schemes.find{|s| s.base_scheme_id == scheme_name}

          colors = []
          theme.colors.each do |color|
            colors << {name: color.name, hex: color.hex }
          end

          attrs = {
            name: I18n.t("wizard.step.colors.fields.theme_id.choices.#{scheme_name}.label"),
            colors: colors,
            base_scheme_id: scheme_name
          }

          scheme = ColorScheme.where(via_wizard: true).first
          if scheme.present?
            attrs[:colors] = colors
            revisor = ColorSchemeRevisor.new(scheme, attrs)
            revisor.revise
          else
            attrs[:via_wizard] = true
            scheme = ColorScheme.new(attrs)
            scheme.save!
          end

          default_theme = Theme.find_by(key: SiteSetting.default_theme_key)
          unless default_theme
            default_theme = Theme.new(name: "Default Theme", user_id: -1)
          end
          default_theme.color_scheme_id = scheme.id
          default_theme.save!
          SiteSetting.default_theme_key = default_theme.key
        end
      end

      @wizard.append_step('logos') do |step|
        step.add_field(id: 'logo_url', type: 'image', value: SiteSetting.logo_url)
        step.add_field(id: 'logo_small_url', type: 'image', value: SiteSetting.logo_small_url)

        step.on_update do |updater|
          updater.apply_settings(:logo_url, :logo_small_url)
        end
      end

      @wizard.append_step('icons') do |step|
        step.add_field(id: 'favicon_url', type: 'image', value: SiteSetting.favicon_url)
        step.add_field(id: 'apple_touch_icon_url', type: 'image', value: SiteSetting.apple_touch_icon_url)

        step.on_update do |updater|
          updater.apply_settings(:favicon_url, :apple_touch_icon_url)
        end
      end

      @wizard.append_step('homepage') do |step|

        current = SiteSetting.top_menu.starts_with?("categories") ? "categories" : "latest"

        style = step.add_field(id: 'homepage_style', type: 'dropdown', required: true, value: current)
        style.add_choice('latest')
        style.add_choice('categories')
        step.add_field(id: 'homepage_preview', type: 'component')

        step.on_update do |updater|
          top_menu = "latest|new|unread|top|categories"
          top_menu = "categories|latest|new|unread|top" if updater.fields[:homepage_style] == 'categories'
          updater.update_setting(:top_menu, top_menu)
        end
      end

      @wizard.append_step('emoji') do |step|
        sets = step.add_field({
          id: 'emoji_set',
          type: 'radio',
          required: true,
          value: SiteSetting.emoji_set
        })

        emoji = ["smile", "+1", "tada", "poop"]

        EmojiSetSiteSetting.values.each do |set|
          imgs = emoji.map do |e|
            "<img src='/images/emoji/#{set[:value]}/#{e}.png'>"
          end

          sets.add_choice(set[:value], {
            label: I18n.t("js.#{set[:name]}"),
            extra_label: "<span class='emoji-preview'>#{imgs.join}</span>"
          })

          step.on_update do |updater|
            updater.apply_settings(:emoji_set)
          end
        end
      end

      @wizard.append_step('invites') do |step|

        staff_count = User.where("moderator = true or admin = true").where("id <> ?", Discourse.system_user.id).count
        step.add_field(id: 'staff_count', type: 'component', value: staff_count)

        step.add_field(id: 'invite_list', type: 'component')

        step.on_update do |updater|
          users = JSON.parse(updater.fields[:invite_list])

          users.each do |u|
            args = {}
            args[:moderator] = true if u['role'] == 'moderator'
            Invite.create_invite_by_email(u['email'], @wizard.user, args)
          end
        end
      end

      DiscourseEvent.trigger(:build_wizard, @wizard)

      @wizard.append_step('finished') do |step|
        step.banner = "finished.png"
      end
      @wizard
    end

  protected

    def replace_company(updater, raw, field_name)
      old_value = SiteSetting.send(field_name)
      old_value = field_name if old_value.blank?

      new_value = updater.fields[field_name.to_sym]
      new_value = field_name if new_value.blank?

      raw.gsub!(old_value, new_value)
    end
  end
end

