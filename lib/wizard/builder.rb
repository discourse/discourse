class Wizard
  class Builder

    def initialize(user)
      @wizard = Wizard.new(user)
    end

    def build
      @wizard.append_step('locale') do |step|
        languages = step.add_field(id: 'default_locale',
                                   type: 'dropdown',
                                   required: true,
                                   value: SiteSetting.default_locale)

        LocaleSiteSetting.values.each do |locale|
          languages.add_choice(locale[:value], label: locale[:name])
        end

        step.on_update do |updater, fields|
          old_locale = SiteSetting.default_locale
          updater.update_setting_field(:default_locale, fields, :default_locale)
          updater.refresh_required = true if old_locale != fields[:default_locale]
        end
      end

      @wizard.append_step('forum-title') do |step|
        step.add_field(id: 'title', type: 'text', required: true, value: SiteSetting.title)
        step.add_field(id: 'site_description', type: 'text', required: true, value: SiteSetting.site_description)

        step.on_update do |updater, fields|
          updater.update_setting_field(:title, fields, :title)
          updater.update_setting_field(:site_description, fields, :site_description)
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

        step.on_update do |updater, fields|
          updater.update_setting(:login_required, fields[:privacy] == 'restricted')
          updater.update_setting(:invite_only, fields[:privacy] == 'restricted')
        end
      end

      @wizard.append_step('contact') do |step|
        step.add_field(id: 'contact_email', type: 'text', required: true, value: SiteSetting.contact_email)
        step.add_field(id: 'contact_url', type: 'text', value: SiteSetting.contact_url)
        step.add_field(id: 'site_contact_username', type: 'text', value: SiteSetting.site_contact_username)

        step.on_update do |updater, fields|
          updater.update_setting_field(:contact_email, fields, :contact_email)
          updater.update_setting_field(:contact_url, fields, :contact_url)
          updater.update_setting_field(:site_contact_username, fields, :site_contact_username)
        end
      end

      @wizard.append_step('colors') do |step|
        theme_id = ColorScheme.where(via_wizard: true).pluck(:theme_id)
        theme_id = theme_id.present? ? theme_id[0] : 'default'

        themes = step.add_field(id: 'theme_id', type: 'dropdown', required: true, value: theme_id)
        ColorScheme.themes.each {|t| themes.add_choice(t[:id], data: t) }
        step.add_field(id: 'theme_preview', type: 'component')

        step.on_update do |updater, fields|
          scheme_name = fields[:theme_id]

          theme = ColorScheme.themes.find {|s| s[:id] == scheme_name }

          colors = []
          theme[:colors].each do |name, hex|
            colors << {name: name, hex: hex[1..-1] }
          end

          attrs = {
            enabled: true,
            name: I18n.t("wizard.step.colors.fields.color_scheme.options.#{scheme_name}"),
            colors: colors,
            theme_id: scheme_name
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
        end
      end

      @wizard.append_step('logos') do |step|
        step.add_field(id: 'logo_url', type: 'image', value: SiteSetting.logo_url)
        step.add_field(id: 'logo_small_url', type: 'image', value: SiteSetting.logo_small_url)
        step.add_field(id: 'favicon_url', type: 'image', value: SiteSetting.favicon_url)
        step.add_field(id: 'apple_touch_icon_url', type: 'image', value: SiteSetting.apple_touch_icon_url)

        step.on_update do |updater, fields|
          updater.update_setting_field(:logo_url, fields, :logo_url)
          updater.update_setting_field(:logo_small_url, fields, :logo_small_url)
          updater.update_setting_field(:favicon_url, fields, :favicon_url)
          updater.update_setting_field(:apple_touch_icon_url, fields, :apple_touch_icon_url)
        end
      end

      @wizard.append_step('finished')
      @wizard
    end

  end
end

