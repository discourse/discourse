class Wizard
  class StepUpdater
    include ActiveModel::Model

    def initialize(current_user, id)
      @current_user = current_user
      @id = id
    end

    def update(fields)
      updater_method = "update_#{@id.underscore}".to_sym
      send(updater_method, fields.symbolize_keys) if respond_to?(updater_method)
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

    def success?
      @errors.blank?
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
