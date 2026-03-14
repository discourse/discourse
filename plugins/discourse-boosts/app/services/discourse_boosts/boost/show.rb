# frozen_string_literal: true

module DiscourseBoosts
  class Boost::Show
    include Service::Base

    params do
      attribute :boost_id, :integer

      validates :boost_id, presence: true
    end

    model :boost
    policy :can_see_boost

    private

    def fetch_boost(params:)
      DiscourseBoosts::Boost.includes(:post, :user).find_by(id: params.boost_id)
    end

    def can_see_boost(guardian:, boost:)
      guardian.can_see?(boost.post)
    end
  end
end
