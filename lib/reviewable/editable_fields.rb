require_dependency 'reviewable/collection'

class Reviewable < ActiveRecord::Base
  class EditableFields < Reviewable::Collection
    class Field < Item
      attr_reader :type

      def initialize(id, type)
        super(id)
        @type = type
      end
    end

    def add(id, type)
      @content << Field.new(id, type)
    end
  end
end
