# frozen_string_literal: true

class ServiceBase
  class ServiceFailureError < StandardError
    attr_reader :result

    def initialize(result)
      @result = result
    end
  end

  attr_reader :guardian

  include HasErrors

  FAIL_TYPES =
    Enum.new(permission: 1, validation: 2, record_not_found: 3, unexpected: 4, uncaught: 99)

  def fail_permissions!(messages)
    raise ServiceFailureError.new(
            ServiceResult.failed(errors: messages, failure_type: FAIL_TYPES[:permission]),
          )
  end

  def fail_validation!(messages)
    raise ServiceFailureError.new(
            ServiceResult.failed(errors: messages, failure_type: FAIL_TYPES[:validation]),
          )
  end

  def fail_record_not_found!(message)
    raise ServiceFailureError.new(
            ServiceResult.failed(errors: messages, failure_type: FAIL_TYPES[:record_not_found]),
          )
  end

  def fail_unexpected!(message)
    raise ServiceFailureError.new(
            ServiceResult.failed(errors: messages, failure_type: FAIL_TYPES[:unexpected]),
          )
  end

  def fail_uncaught!(raised_error)
    ServiceResult.failed(
      errors: uncaught_error_message,
      failure_type: FAIL_TYPES[:uncaught],
      raised_error: raised_error,
    )
  end

  def execute_service_call
    result = nil
    begin
      yield
    rescue ActiveRecord::RecordNotFound => err
      result = fail_record_not_found!(err.message)
    rescue Discourse::InvalidAccess => err
      result = fail_permissions!(err.message)
    rescue ServiceBase::ServiceFailureError => err
      result = err.result
    rescue => err
      Discourse.warn_exception(err)
      result = fail_uncaught!(err)
    end

    result || ServiceResult.succeeded(message: success_message, service_data: success_data)
  end

  def enqueue_job(job, args)
    Jobs.enqueue(job, args)
  end

  def enqueue_job_at(at, job, args)
    Jobs.enqueue_at(at, job, args)
  end

  def uncaught_error_message
    "Failed to complete operation."
  end

  def success_message
    nil
  end

  def success_data
    nil
  end

  def log_staff_action(key, params = {})
    StaffActionLogger.new(guardian.user).log_custom(key, params)
  end

  def log_message(level, message)
    Rails.logger.send(level, message)
  end

  def log_user_history(target_user_id:, acting_user_id:, action:)
    UserHistory.create!(
      target_user_id: target_user_id,
      acting_user_id: acting_user_id,
      action: UserHistory.actions[action],
    )
  end

  def error_messages
    errors.full_messages
  end

  def initialize(guardian)
    @guardian = guardian
  end
end
