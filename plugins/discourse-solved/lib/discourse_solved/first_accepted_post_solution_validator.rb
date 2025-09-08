# frozen_string_literal: true

module DiscourseSolved
  class FirstAcceptedPostSolutionValidator
    def self.check(post, trust_level:)
      return false if post.archetype != Archetype.default
      return false if !post&.user&.human?

      if trust_level != "any" && TrustLevel.compare(post&.user&.trust_level, trust_level.to_i)
        return false
      end

      !DiscourseSolved::SolvedTopic
        .joins(:answer_post)
        .where("posts.user_id = ? AND posts.id != ?", post.user_id, post.id)
        .exists?
    end
  end
end
