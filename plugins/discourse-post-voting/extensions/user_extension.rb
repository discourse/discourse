# frozen_string_literal: true

module PostVoting
  module UserExtension
    class << self
      def included(base)
        base.has_many :post_voting_votes
      end
    end
  end
end
