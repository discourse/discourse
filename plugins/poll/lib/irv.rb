# frozen_string_literal: true

class DiscoursePoll::Irv
  def self.irv_outcome(starting_votes)
    current_votes = starting_votes.dup
    round_activity = []
    round = 0
    while true
      round += 1
      # Count the first place votes for each candidate
      tally = tally_votes(current_votes)

      # Check for a majority
      max_votes = tally.values.max
      total_votes = tally.values.sum
      potential_winners = tally.select { |k, v| v == max_votes }

      # If a majority is found or only one candidate remains
      if max_votes > total_votes / 2 || potential_winners.count == 1
        round_activity << { round: round, majority: potential_winners.keys.first, eliminated: nil }
        return(
          {
            tied: false,
            tied_candidates: nil,
            winner: true,
            winning_candidate: potential_winners.keys.first,
            round_activity: round_activity,
          }
        )
      end

      # Find the candidate(s) with the least votes
      min_votes = tally.values.min
      losers = tally.select { |k, v| v == min_votes }.keys

      # Remove the candidate with the least votes
      current_votes.each do |vote|
        # losers.each { |loser| vote.delete(loser) }
        vote.reject! { |candidate| losers.include?(candidate) }
      end

      all_empty = current_votes.all? { |arr| arr.empty? }
      if all_empty
        round_activity << { round: round, majority: nil, eliminated: losers }
        return(
          {
            tied: true,
            tied_candidates: potential_winners.keys,
            winner: nil,
            winning_candidate: nil,
            round_activity: round_activity,
          }
        )
      end
      round_activity << { round: round, majority: nil, eliminated: losers }
    end
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
end
