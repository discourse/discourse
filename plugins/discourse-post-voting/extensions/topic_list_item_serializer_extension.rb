# frozen_string_literal: true

module PostVoting
  module TopicListItemSerializerExtension
    class << self
      def included(base)
        base.attributes :is_post_voting
      end
    end

    def is_post_voting
      object.is_post_voting?
    end

    def include_is_post_voting?
      object.is_post_voting?
    end
  end
end
