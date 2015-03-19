module JsonError

  def create_errors_json(obj, type=nil)
    errors = create_errors_array obj
    errors[:error_type] = type if type
    errors
  end

  private

  def create_errors_array(obj)
    # If we're passed a string, assume that is the error message
    return { errors: [obj] } if obj.is_a?(String)

    # If it's an AR exception target the record
    obj = obj.record if obj.is_a?(ActiveRecord::RecordInvalid)

    # If it looks like an activerecord object, extract its messages
    return { errors: obj.errors.full_messages } if obj.respond_to?(:errors) && obj.errors.present?

    # If we're passed an array, it's an array of error messages
    return { errors: obj.map(&:to_s) } if obj.is_a?(Array) && obj.present?

    # Log a warning (unless obj is nil)
    Rails.logger.warn("create_errors_json called with unrecognized type: #{obj.inspect}") if obj

    # default to a generic error
    JsonError.generic_error
  end

  def self.generic_error
    { errors: [I18n.t('js.generic_error')] }
  end

end
