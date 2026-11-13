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

  module JourneyLinearSimulator
    def bounded_simulator
      @bounded_simulator ||= self.class.new(tt.dup.extend(JourneyTransitionTableLinearMove))
    end

    def memos(string)
      transition_table = tt
      static_tokens = ActionDispatch::Journey::GTG::Simulator::STATIC_TOKENS
      state = ActionDispatch::Journey::GTG::Simulator::INITIAL_STATE

      pos = 0
      eos = string.bytesize

      while pos < eos
        start_index = pos
        pos += 1

        if (token = static_tokens[string.getbyte(start_index)])
          state = transition_table.move(state, string, token, start_index, false)
        else
          pos += 1 while pos < eos && static_tokens[string.getbyte(pos)].nil?

          token = string.byteslice(start_index, pos - start_index)
          state = transition_table.move(state, string, token, start_index, true)
        end
      end

      acceptance_states = []
      states_count = state.size
      i = 0
      while i < states_count
        if state[i + 1].nil?
          s = state[i]
          acceptance_states.concat(transition_table.memo(s)) if transition_table.accepting?(s)
        end
        i += 2
      end

      acceptance_states.empty? ? yield : acceptance_states
    end
  end

  module JourneyRouterVerifiedCandidates
    BOUNDED_SIMULATION_MIN_BYTES = 129
    BOUNDED_SIMULATION_MIN_SEPARATORS = 65
    private_constant :BOUNDED_SIMULATION_MIN_BYTES, :BOUNDED_SIMULATION_MIN_SEPARATORS

    private

    def filter_routes(path)
      if path.bytesize >= BOUNDED_SIMULATION_MIN_BYTES &&
           (path.valid_encoding? ? path : path.b).count("./?") >= BOUNDED_SIMULATION_MIN_SEPARATORS
        simulator
          .bounded_simulator
          .memos(path) { [] }
          .uniq
          .select { |route| route.path.match?(path) }
      else
        simulator.memos(path) { [] }
      end
    end
  end

  private_constant :JourneyTransitionTableLinearMove
end

ActionDispatch::Journey::GTG::Simulator.prepend(FreedomPatches::JourneyLinearSimulator)
ActionDispatch::Journey::Router.prepend(FreedomPatches::JourneyRouterVerifiedCandidates)
