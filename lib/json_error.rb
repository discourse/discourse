module JsonError

  def create_errors_json(obj)

    # If we're passed a string, assume that is the error message
    return {errors: [obj]} if obj.is_a?(String)

    # If it looks like an activerecord object, extract its messages
    return {errors: obj.errors.full_messages } if obj.respond_to?(:errors) && obj.errors.present?

    # default to a generic error
    JsonError.generic_error
  end

  private

    def self.generic_error
      {errors: [I18n.t('js.generic_error')]}
    end

end
