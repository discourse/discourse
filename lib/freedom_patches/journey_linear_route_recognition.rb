# frozen_string_literal: true

if !Gem::Requirement.new("~> 8.1.0").satisfied_by?(ActionPack.gem_version)
  raise "Check whether Rails now recognizes routes in linear time and remove #{__FILE__}"
end

module FreedomPatches
  module JourneyTransitionTableLinearMove
    def move(t, full_string, token, start_index, token_matches_default)
      return [] if t.empty?

      next_states = []
      seen = {}
      pending = {}

      i = 0
      while i < t.size
        s = t[i]
        previous_start = t[i + 1]

        if previous_start.nil?
          if token_matches_default && (std_state = @stdparam_states[s])
            add_state(next_states, seen, std_state)
          end

          if (states = @string_states[s]) && (state = states[token])
            add_state(next_states, seen, state)
          end
        end

        if (states = @regexp_states[s])
          states.each do |re, v|
            next if v.nil?
            add_state(next_states, seen, v) if previous_start || re.match?(token)
          end

          if !pending.key?(s)
            pending[s] = true
            next_states << s << (previous_start || start_index)
          end
        end

        i += 2
      end

      next_states
    end

    private

    def add_state(next_states, seen, state)
      return if seen.key?(state)

      seen[state] = true
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
