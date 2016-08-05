# Helper functions for dealing with errors and objects that have
# child objects with errors
module HasErrors
  attr_reader :errors

  def errors
    @errors ||= ActiveModel::Errors.new(self)
  end

  def validate_child(obj)
    return true if obj.valid?
    add_errors_from(obj)
    false
  end

  def rollback_with!(obj, error)
    obj.errors.add(:base, error)
    rollback_from_errors!(obj)
  end

  def rollback_from_errors!(obj)
    add_errors_from(obj)
    raise ActiveRecord::Rollback.new
  end

  def add_errors_from(obj)
    obj.errors.full_messages.each do |msg|
      errors[:base] << msg unless errors[:base].include?(msg)
    end
  end

end
