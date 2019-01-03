class Reviewable < ActiveRecord::Base
  class Collection
    class Item
      include ActiveModel::Serialization
      attr_reader :id

      def initialize(id)
        @id = id
      end
    end

    def initialize(reviewable, guardian, args = nil)
      args ||= {}

      @reviewable, @guardian, @args = reviewable, guardian, args
      @content = []
    end

    def has?(id)
      @content.any? { |a| a.id.to_s == id.to_s }
    end

    def blank?
      @content.blank?
    end

    def present?
      !blank?
    end

    def each
      @content.each { |i| yield i }
    end

    def to_a
      @content
    end
  end
end
