# frozen_string_literal: true

class ServiceResult
  attr_reader :errors, :message, :service_data, :raised_error

  def self.succeeded(message: nil, service_data: nil)
    ServiceResult.new(:success, message: message, service_data: service_data)
  end

  def self.failed(errors:, failure_type:, service_data: nil, raised_error: nil)
    ServiceResult.new(
      :failed,
      failure_type: failure_type,
      errors: Array.wrap(errors),
      service_data: service_data,
      raised_error: raised_error,
    )
  end

  def initialize(
    state,
    message: nil,
    failure_type: nil,
    errors: nil,
    service_data: nil,
    raised_error: nil
  )
    @state = state
    @message = message
    @errors = errors
    @failure_type = failure_type
    @service_data = service_data.present? ? OpenStruct.new(service_data) : nil
    @raised_error = raised_error
  end

  def failed?
    @state == :failed
  end

  def succeeded?
    @state == :success
  end

  def http_status
    return 200 if succeeded?
    case @failure_type
    when ServiceBase::FAIL_TYPES[:permission]
      403
    when ServiceBase::FAIL_TYPES[:record_not_found]
      404
    when ServiceBase::FAIL_TYPES[:validation], ServiceBase::FAIL_TYPES[:unexpected],
         ServiceBase::FAIL_TYPES[:uncaught]
      400
    end
  end
end
