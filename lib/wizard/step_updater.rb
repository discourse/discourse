class Wizard
  class StepUpdater
    include ActiveModel::Model

    attr_accessor :refresh_required

    def initialize(current_user, step)
      @current_user = current_user
      @step = step
      @refresh_required = false
    end

    def update(fields)
      @step.updater.call(self, fields) if @step.updater.present?
    end

    def success?
      @errors.blank?
    end

    def refresh_required?
      @refresh_required
    end

    def update_setting(id, value)
      value.strip! if value.is_a?(String)
      SiteSetting.set_and_log(id, value, @current_user) if SiteSetting.send(id) != value
    end

    def update_setting_field(id, fields, field_id)
      update_setting(id, fields[field_id])
    rescue Discourse::InvalidParameters => e
      errors.add(field_id, e.message)
    end

  end
end
