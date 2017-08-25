module AnnotatorStore
  class Collection < ActiveRecord::Base
    # Associations
    has_and_belongs_to_many :tags

    # Validations
    validates :name, presence: true
    validates :creator, presence: true

  end
end


