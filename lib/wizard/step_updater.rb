class Wizard
  class StepUpdater
    include ActiveModel::Model

    attr_accessor :refresh_required, :fields

    def initialize(current_user, step, fields)
      @current_user = current_user
      @step = step
      @refresh_required = false
      @fields = fields
    end

    def update
      @step.updater.call(self) if @step.present? && @step.updater.present?

      if success?
        logger = StaffActionLogger.new(@current_user)
        logger.log_wizard_step(@step)
      end
    end

    def success?
      @errors.blank?
    end

    def refresh_required?
      @refresh_required
    end

    def update_setting(id, value)
      value.strip! if value.is_a?(String)

      if !value.is_a?(Upload) && SiteSetting.type_supervisor.get_type(id) == :upload
        value = Upload.get_from_url(value) || ''
      end

      SiteSetting.set_and_log(id, value, @current_user) if SiteSetting.send(id) != value
    end

    def apply_setting(id)
      update_setting(id, @fields[id])
    rescue Discourse::InvalidParameters => e
      errors.add(id, e.message)
    end

    def ensure_changed(id)
      errors.add(id, '') if @fields[id] == SiteSetting.defaults[id]
    end

    def apply_settings(*ids)
      ids.each { |id| apply_setting(id) }
    end

  end
end
