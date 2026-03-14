# frozen_string_literal: true

module DiscourseBoosts
  class ReviewableBoostSerializer < ReviewableSerializer
    payload_attributes :boost_cooked

    def created_from_flag?
      true
    end
  end
end
