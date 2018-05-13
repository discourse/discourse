module AnnotatorStore
  class Tag < ActiveRecord::Base

    attr_accessor :merge_tag_id

    # https://github.com/stefankroes/ancestry
    has_ancestry

    # Associations
    belongs_to :creator, class_name: 'User'
    has_many :annotations, dependent: :destroy

    # Validations
    validates :name, presence: true, uniqueness: {scope: [:ancestry, :creator_id], case_sensitive: false}
    validates :creator, presence: true

    # Callbacks
    after_save do
      if merge_tag_id.present?
        t = AnnotatorStore::Tag.find(merge_tag_id)
        t.annotations.update_all(tag_id: id)
        t.destroy
      end
    end


    # --- Class Finder Methods --- #

    def self.with_annotations_count
      select('annotator_store_tags.*, count(annotator_store_annotations.id) AS annotations_count').
        joins('LEFT OUTER JOIN annotator_store_annotations on annotator_store_annotations.tag_id = annotator_store_tags.id').
        group('annotator_store_tags.id')
    end


    # --- Instance Methods --- #


  end
end
