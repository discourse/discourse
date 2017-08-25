module AnnotatorStore
  class CollectionsTag < ActiveRecord::Base


    # --- Associations --- #

    belongs_to :collection
    belongs_to :tag


    # --- Validations --- #

    validates :collection, presence: true
    validates :tag, presence: true


  end
end
