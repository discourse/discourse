# frozen_string_literal: true

class UniqueAmongValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if !duplicates(record.class, record, attribute, value).exists?

    dupe = duplicates(options[:collection].call(record), record, attribute, value).first
    record.errors.add(:base, options[:message], url: dupe.url) if dupe
  end

  private

  def duplicates(scope, record, attribute, value)
    scope = scope.where("lower(#{attribute}) = ?", value.downcase)
    scope = scope.where.not(id: record.id) if record.persisted?
    scope
  end
end
