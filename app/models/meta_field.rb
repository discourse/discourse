class MetaField < ActiveRecord::Base
  belongs_to :meta_object
  belongs_to :meta_column
  belongs_to :fieldable, polymorphic: true

  validates :meta_column_id, presence: true

  validate :validate_string_length, if: -> { fieldable.is_a?(StringMetaField) }
  validate :validate_integer_value, if: -> { fieldable.is_a?(IntegerMetaField) }
  validate :validate_enum_value, if: -> { fieldable.is_a?(EnumMetaField) }

  private

  def validate_string_length
    detailable = meta_column.detailable
    min_length = detailable.min_length
    max_length = detailable.max_length
    value = fieldable.value

    if value.length < min_length
      self.errors.add(:value, "must be at least #{min_length} characters long")
    elsif value.length > max_length
      self.errors.add(:value, "must be at most #{max_length} characters long")
    end
  end

  def validate_integer_value
    detailable = meta_column.detailable
    min_value = detailable.min_value
    max_value = detailable.max_value
    value = fieldable.value

    if value < min_value
      self.errors.add(:value, "must be at least #{min_value}")
    elsif value > max_value
      self.errors.add(:value, "must be at most #{max_value}")
    end
  end

  def validate_enum_value
    values = meta_column.detailable.values
    value = fieldable.value
    self.errors.add(:value, "must be one of #{values.join(", ")}") unless values.include?(value)
  end
end
