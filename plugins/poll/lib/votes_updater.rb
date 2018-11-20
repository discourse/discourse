module DiscoursePoll
  class VotesUpdater
    def self.merge_users!(source_user, target_user)
      post_ids = PostCustomField.where(name: DiscoursePoll::VOTES_CUSTOM_FIELD)
        .where("value :: JSON -> ? IS NOT NULL", source_user.id.to_s)
        .pluck(:post_id)

      post_ids.each do |post_id|
        DistributedMutex.synchronize("discourse_poll-#{post_id}") do
          post = Post.find_by(id: post_id)
          update_votes(post, source_user, target_user) if post
        end
      end
    end

    def self.update_votes(post, source_user, target_user)
      polls = post.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD]
      votes = post.custom_fields[DiscoursePoll::VOTES_CUSTOM_FIELD]
      return if polls.nil? || votes.nil? || !votes.has_key?(source_user.id.to_s)

      if votes.has_key?(target_user.id.to_s)
        remove_votes(polls, votes, source_user)
      else
        replace_voter_id(polls, votes, source_user, target_user)
      end

      post.save_custom_fields(true)
    end

    def self.remove_votes(polls, votes, source_user)
      votes.delete(source_user.id.to_s).each do |poll_name, option_ids|
        poll = polls[poll_name]
        next unless poll && option_ids

        poll["options"].each do |option|
          if option_ids.include?(option["id"])
            option["votes"] -= 1

            voter_ids = option["voter_ids"]
            voter_ids.delete(source_user.id) if voter_ids
          end
        end
      end
    end

    def self.replace_voter_id(polls, votes, source_user, target_user)
      votes[target_user.id.to_s] = votes.delete(source_user.id.to_s)

      polls.each_value do |poll|
        next unless poll["public"] == "true"

        poll["options"].each do |option|
          voter_ids = option["voter_ids"]
          voter_ids << target_user.id if voter_ids&.delete(source_user.id)
        end
      end
    end
  end
end
