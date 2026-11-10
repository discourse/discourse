# frozen_string_literal: true

module DiscourseAi
  module Completions
    # Work is new generation/evidence, never request usage or a monetary estimate.
    class TurnWorkBudget
      MAX_FINAL_ANSWER_TOKENS = 2048
      # Thinking room on top of the visible final-answer cap, so a model
      # that cannot disable thinking does not spend the answer budget
      # deliberating. The final provider ceiling is the sum of the two.
      MAX_FINAL_THINKING_ALLOWANCE = 2048
      PLANNING_RESERVE_TOKENS = 2500

      Reservation = Struct.new(:tokens, :owner, :released)
      private_constant :Reservation

      attr_reader :limit

      def initialize(limit:, used: 0, event_ids: [], final_answer_claimed: false, parent: nil)
        @limit = limit.to_i
        @used = used.to_i
        if @limit <= 0 || @used < 0
          raise ArgumentError, "work limit must be positive and usage nonnegative"
        end
        @reserved = 0
        @parent = parent
        @root = parent ? parent.root : self
        if !parent
          @mutex = Mutex.new
          @event_ids = event_ids.to_set
          @final_answer_claimed = final_answer_claimed
        end
      end

      def child(limit:)
        self.class.new(limit: limit, parent: self)
      end

      def used
        synchronize { @used }
      end

      def remaining
        synchronize { available }
      end

      def debit(tokens, event_id:)
        synchronize do
          return false if root.event_ids.include?(event_id)
          root.event_ids.add(event_id)
          ancestors.each { |budget| budget.add_used([tokens.to_i, 0].max) }
          true
        end
      end

      def generation_options(options, maximum:, final: false, tools: false, root: false)
        resolved = options.dup
        thinking_allowance = resolved.delete(:thinking_allowance)

        # Finalization is the bot's own bounded policy ("answer now"): the
        # visible answer gets MAX_FINAL_ANSWER_TOKENS, with a separate
        # thinking allowance on top bounding the provider ceiling.
        if final
          total_ceiling = MAX_FINAL_ANSWER_TOKENS + MAX_FINAL_THINKING_ALLOWANCE
          maximum = [maximum || total_ceiling, total_ceiling].min
        end

        # A visible-response intent is not a provider ceiling: derive the
        # provider total (visible + thinking allowance) and let any genuine
        # provider ceiling (explicit max_tokens or model cap) bound it.
        if !final && options[:max_response_tokens].to_i.positive?
          derived =
            options[:max_response_tokens].to_i +
              (thinking_allowance || ThinkingConfig.response_allowance(options[:thinking_effort]))
          maximum = maximum ? [maximum, derived].min : derived
        end

        # Nothing configured means no provider ceiling is sent at all; the
        # budget still accounts for actual usage after each generation.
        if maximum
          available = remaining
          maximum = [maximum, available].min if !final || !root
          maximum = [maximum, [available / 2, 1].max].min if !final && tools
          resolved = resolved.merge(max_tokens: maximum, max_tokens_is_total: true)
        else
          resolved.delete(:max_tokens)
          resolved.delete(:max_tokens_is_total)
        end

        if final
          existing_response = resolved[:max_response_tokens].to_i
          resolved[:max_response_tokens] = [
            existing_response.positive? ? existing_response : MAX_FINAL_ANSWER_TOKENS,
            MAX_FINAL_ANSWER_TOKENS,
            maximum,
          ].min
          resolved[:thinking_effort] = "none"
        end

        resolved
      end

      # Capacity/history checks must precede the root-final claim; a duplicate claim returns nil.
      def reserve_generation_output(provider_output, max_tokens:, final: false, root: false)
        # With no provider ceiling, the work reservation is a planning
        # estimate only (context admission uses the provider output
        # separately); it must not consume the whole remaining budget and
        # starve helpers invoked while this generation is in flight.
        maximum =
          if max_tokens.nil?
            [provider_output.to_i, PLANNING_RESERVE_TOKENS].min
          else
            [provider_output.to_i, max_tokens.to_i].max
          end
        if final && max_tokens && provider_output.to_i > max_tokens.to_i
          raise ContextPreparation::Error.new("final_output_limit")
        end
        # With no provider ceiling the generation is accounted post-hoc, so
        # admission soft-reserves what work remains instead of rejecting.
        reservation =
          reserve_output(maximum, final: final && root, allow_overshoot: root || max_tokens.nil?)
        raise ContextPreparation::Error.new("turn_budget_exhausted") if !reservation
        if final && root && !claim_final_answer
          release_output(reservation)
          return nil
        end
        reservation
      end

      # Reserve the provider output ceiling; root-only soft overshoot never raises the work limit.
      def reserve_output(maximum, final: false, allow_overshoot: false)
        synchronize do
          return nil if !final && !allow_overshoot && maximum.to_i > available
          tokens = final && self == root ? maximum.to_i : [maximum.to_i, available].min
          return nil if tokens <= 0
          ancestors.each { |budget| budget.add_reserved(tokens) }
          Reservation.new(tokens, self, false)
        end
      end

      def release_output(reservation)
        return if !reservation
        synchronize do
          return if reservation.owner != self || reservation.released
          reservation.released = true
          ancestors.each { |budget| budget.add_reserved(-reservation.tokens) }
        end
      end

      def claim_final_answer
        synchronize do
          return false if self != root || root.final_answer_claimed
          root.final_answer_claimed = true
          true
        end
      end

      def snapshot
        synchronize do
          raise ArgumentError, "cannot persist in-flight work" if @reserved != 0
          {
            limit: limit,
            used: @used,
            event_ids: root.event_ids.to_a,
            final_answer_claimed: root.final_answer_claimed,
          }
        end
      end

      protected

      attr_reader :root, :event_ids, :mutex
      attr_accessor :final_answer_claimed

      def add_used(tokens)
        @used += tokens
      end

      def add_reserved(tokens)
        @reserved += tokens
      end

      def unreserved
        limit - @used - @reserved
      end

      def available
        ancestors.map { |budget| budget.unreserved }.min.clamp(0, [limit, 0].max)
      end

      def ancestors
        @parent ? [self, *@parent.ancestors] : [self]
      end

      def synchronize(&block)
        root.mutex.synchronize(&block)
      end
    end
  end
end
