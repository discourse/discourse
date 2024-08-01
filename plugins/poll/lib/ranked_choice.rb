# frozen_string_literal: true

class DiscoursePoll::RankedChoice
  MAX_ROUNDS = 50

  def self.outcome(poll_id)
    options = PollOption.where(poll_id: poll_id).map { |hash| { id: hash.digest, html: hash.html } }

    ballot = []

    #Fetch all votes for the poll in a single query
    votes =
      PollVote
        .where(poll_id: poll_id)
        .select(:user_id, :poll_option_id, :rank)
        .order(:user_id, :rank)
        .includes(:poll_option) # Eager load poll options
    # Group votes by user_id
    votes_by_user = votes.group_by(&:user_id)
    # Build the ballot
    votes_by_user.each do |user_id, user_votes|
      ballot_paper =
        user_votes.select { |vote| vote.rank > 0 }.map { |vote| vote.poll_option.digest }
      ballot << ballot_paper
    end

    DiscoursePoll::RankedChoice.run(ballot, options) if ballot.length > 0
  end

  def self.run(starting_votes, options)
    current_votes = starting_votes
    round_activity = []
    potential_winners = []
    round = 0
    while round < MAX_ROUNDS
      round += 1

      # Count the first place votes for each candidate
      tally = tally_votes(current_votes)

      max_votes = tally.values.max

      # Find the candidate(s) with the most votes
      potential_winners = find_potential_winners(tally, max_votes)

      # Check for a majority and return if found
      if majority_check(tally, max_votes)
        majority_candidate = enrich(potential_winners.keys.first, options)

        round_activity << { round: round, majority: majority_candidate, eliminated: nil }

        return(
          {
            tied: false,
            tied_candidates: nil,
            winner: true,
            winning_candidate: majority_candidate,
            round_activity: round_activity,
          }
        )
      end

      # Find the candidate(s) with the least votes
      losers = identify_losers(tally)

      # Remove the candidate with the least votes
      current_votes.each { |vote| vote.reject! { |candidate| losers.include?(candidate) } }

      losers = losers.map { |loser| enrich(loser, options) }

      round_activity << { round: round, majority: nil, eliminated: losers }

      all_empty = current_votes.all? { |arr| arr.empty? }

      if all_empty
        return(
          {
            tied: true,
            tied_candidates: losers,
            winner: nil,
            winning_candidate: nil,
            round_activity: round_activity,
          }
        )
      end
    end

    potential_winners =
      potential_winners.keys.map { |potential_winner| enrich(potential_winner, options) }

    {
      tied: true,
      tied_candidates: potential_winners,
      winner: nil,
      winning_candidate: nil,
      round_activity: round_activity,
    }
  end

  private

  def self.tally_votes(current_votes)
    tally = Hash.new(0)
    current_votes.each do |vote|
      vote.each { |candidate| tally[candidate] = 0 unless tally.has_key?(candidate) }
    end
    current_votes.each { |vote| tally[vote.first] += 1 if vote.first }
    tally
  end

  def self.find_potential_winners(tally, max_votes)
    tally.select { |k, v| v == max_votes }
  end

  def self.majority_check(tally, max_votes)
    total_votes = tally.values.sum

    max_votes && max_votes > total_votes / 2
  end

  def self.identify_losers(tally)
    min_votes = tally.values.min

    tally.select { |k, v| v == min_votes }.keys
  end

  def self.enrich(digest, options)
    { digest: digest, html: options.find { |option| option[:id] == digest }[:html] }
  end
end
