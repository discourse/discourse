class Wizard
  class StepUpdater
    include ActiveModel::Model

    def initialize(current_user, id)
      @current_user = current_user
      @id = id
      @refresh_required = false
    end

    def update(fields)
      updater_method = "update_#{@id.underscore}".to_sym
      send(updater_method, fields.symbolize_keys) if respond_to?(updater_method)
    end

    def update_locale(fields)
      old_locale = SiteSetting.default_locale
      update_setting(:default_locale, fields, :default_locale)
      @refresh_required = true if old_locale != fields[:default_locale]
    end

    def update_forum_title(fields)
      update_setting(:title, fields, :title)
      update_setting(:site_description, fields, :site_description)
    end

    def update_contact(fields)
      update_setting(:contact_email, fields, :contact_email)
      update_setting(:contact_url, fields, :contact_url)
      update_setting(:site_contact_username, fields, :site_contact_username)
    end

    def update_colors(fields)
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

    def success?
      @errors.blank?
    end

    def refresh_required?
      @refresh_required
    end

    protected

      def update_setting(id, fields, field_id)
        value = fields[field_id]
        value.strip! if value.is_a?(String)

        SiteSetting.set_and_log(id, value, @current_user) if SiteSetting.send(id) != value
      rescue Discourse::InvalidParameters => e
        errors.add(field_id, e.message)
      end

  end
end
