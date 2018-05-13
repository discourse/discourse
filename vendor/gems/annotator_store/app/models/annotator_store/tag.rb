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


    # --- Instance Methods --- #

    def name_with_count
      "#{name} (#{annotations.count})"
    end

  end
end
