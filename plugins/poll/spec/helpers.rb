module Helpers
  def add_anonymous_votes(post, poll, voters, options_with_votes)
    poll["voters"] += voters
    poll["anonymous_voters"] = voters

    poll["options"].each do |option|
      anonymous_votes = options_with_votes[option["id"]] || 0

      if anonymous_votes > 0
        option["votes"] += anonymous_votes
        option["anonymous_votes"] = anonymous_votes
      end
    end

    post.save_custom_fields(true)
  end
end
