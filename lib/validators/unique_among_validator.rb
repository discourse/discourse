# frozen_string_literal: true

class UniqueAmongValidator < ActiveRecord::Validations::UniquenessValidator
  def validate_each(record, attribute, value)
    old_errors = []
    record.errors.each { |error| old_errors << error if error.attribute == attribute }

    # look for any duplicates at all
    super

    new_errors = []
    record.errors.each { |error| new_errors << error if error.attribute == attribute }

    # do nothing further unless there were some duplicates.
    if new_errors.size - old_errors.size != 0
      # now look only in the collection we care about.
      dupes = options[:collection].call(record).where("lower(#{attribute}) = ?", value.downcase)
      dupes = dupes.where("id != ?", record.id) if record.persisted?

      # pop off the error, if it was a false positive
      if !dupes.exists?
        record.errors.delete(attribute)
        old_errors.each { |error| record.errors.add(error.attribute, error.type, **error.options) }
      end
    end
  end
end
