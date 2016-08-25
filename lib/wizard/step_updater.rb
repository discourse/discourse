class Wizard
  class StepUpdater

    attr_accessor :errors

    def initialize(current_user, id)
      @current_user = current_user
      @id = id
      @errors = []
    end

    def update(fields)
      updater_method = "update_#{@id.underscore}".to_sym

      if respond_to?(updater_method)
        send(updater_method, fields.symbolize_keys)
      else
        raise Discourse::InvalidAccess.new
      end
    end

    def update_forum_title(fields)
      update_setting(:title, fields, :title)
      update_setting(:site_description, fields, :site_description)
    end

    def success?
      @errors.blank?
    end

    protected

      def update_setting(id, fields, field_id)
        value = fields[field_id]
        value.strip! if value.is_a?(String)
        SiteSetting.set_and_log(id, value, @current_user)
      rescue Discourse::InvalidParameters => e
        @errors << {field: field_id, description: e.message }
      end

  end
end
