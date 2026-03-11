# frozen_string_literal: true

module DiscourseBoosts
  class Boost::Destroy
    include Service::Base

    params do
      attribute :boost_id, :integer

      validates :boost_id, presence: true
    end

    model :boost
    policy :can_destroy_boost

    step :destroy_boost

    private

    def fetch_boost(params:)
      DiscourseBoosts::Boost.find_by(id: params.boost_id)
    end

    def can_destroy_boost(guardian:, boost:)
      guardian.can_see?(boost.post) &&
        (boost.user_id == guardian.user.id || guardian.can_review_topic?(boost.post.topic))
    end

    def destroy_boost(boost:)
      boost.destroy!
    end
  end
end
