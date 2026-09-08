# frozen_string_literal: true

module DiscourseSolved
  class AcceptedAnswerCache
    @@allowed_accepted_cache = DistributedCache.new("allowed_accepted")

    class << self
      def reset_accepted_answer_cache
        @@allowed_accepted_cache["allowed"] = begin
          Set.new(
            CategoryCustomField.where(
              name: DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD,
              value: "true",
            ).pluck(:category_id),
          )
        end
      end

      def allowed
        @@allowed_accepted_cache["allowed"]
      end
    end
  end
end
