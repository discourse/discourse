# frozen_string_literal: true

if !Gem::Requirement.new("~> 8.1.0").satisfied_by?(ActionPack.gem_version)
  raise "Check whether Rails now recognizes routes in linear time and remove #{__FILE__}"
end

module FreedomPatches
  module JourneyTransitionTableLinearMove
    def move(current_states, _full_string, token, start_index, token_matches_default)
      return [] if current_states.empty?

      next_states = []
      seen_states = {}
      pending_states = {}

      index = 0
      while index < current_states.size
        state = current_states[index]
        previous_start = current_states[index + 1]

        if previous_start.nil?
          if token_matches_default && (next_state = @stdparam_states[state])
            add_state(next_states: next_states, seen_states: seen_states, state: next_state)
          end

          if (transitions = @string_states[state]) && (next_state = transitions[token])
            add_state(next_states: next_states, seen_states: seen_states, state: next_state)
          end
        end

        if (transitions = @regexp_states[state])
          transitions.each do |regexp, destination_state|
            next if destination_state.nil?
            if previous_start || regexp.match?(token)
              add_state(
                next_states: next_states,
                seen_states: seen_states,
                state: destination_state,
              )
            end
          end

          if !pending_states.key?(state)
            pending_states[state] = true
            next_states << state << (previous_start || start_index)
          end
        end

        index += 2
      end

      next_states
    end

    private

    def add_state(next_states:, seen_states:, state:)
      return if seen_states.key?(state)

      seen_states[state] = true
      next_states << state << nil
    end
  end

  module JourneyRouterVerifiedCandidates
    private

    def filter_routes(path)
      super.uniq.select { |route| route.path.match?(path) }
    end
  end
end

ActionDispatch::Journey::GTG::TransitionTable.prepend(
  FreedomPatches::JourneyTransitionTableLinearMove,
)
ActionDispatch::Journey::Router.prepend(FreedomPatches::JourneyRouterVerifiedCandidates)
