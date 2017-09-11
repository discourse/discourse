module AnnotatorStore
  class Range < ActiveRecord::Base
    # Associations
    belongs_to :annotation

    # Validations
    validates :start_offset, presence: true
    validates :end_offset, presence: true
  end
end
