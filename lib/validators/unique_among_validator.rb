# frozen_string_literal: true

class UniqueAmongValidator < ActiveRecord::Validations::UniquenessValidator
  def validate_each(record, attribute, value)
    old_errors = record.errors[attribute].size

    # look for any duplicates at all
    super

    new_errors = record.errors[attribute].size - old_errors

    # do nothing further unless there were some duplicates.
    unless new_errors == 0
      # now look only in the collection we care about.
      dupes = options[:collection].call.where("lower(#{attribute}) = ?", value.downcase)
      dupes = dupes.where("id != ?", record.id) if record.persisted?

      # pop off the error, if it was a false positive
      record.errors[attribute].pop(new_errors) unless dupes.exists?
    end
  end

end
