# frozen_string_literal: true

module Voice
  # Parses a signal request body into ordered per-recipient event batches,
  # enforcing the signaling schema: only offer/answer/candidate events, exact
  # per-type shapes, and hard size/count limits. Any unknown, malformed, or
  # oversized element rejects the entire request before anything is relayed.
  class SignalValidator
    ALLOWED_TYPES = %w[offer answer candidate]
    ALLOWED_CANDIDATE_KEYS = %i[candidate sdpMid sdpMLineIndex usernameFragment]
    MAX_SDP_BYTES = 32_768
    MAX_CANDIDATE_BYTES = 2_048
    MAX_EVENTS_PER_RECIPIENT = 25
    # One short of the largest room the model validates (a stage of 200): a
    # peer never signals more people than can share a room with it. The
    # room's effective capacity usually lowers this further.
    MAX_RECIPIENTS = 199
    MAX_TOTAL_BYTES = 1_048_576

    class << self
      def parse!(payload, room:)
        new(payload, room: room).parse!
      end
    end

    def initialize(payload, room:)
      @payload = payload
      @room = room
      @total_bytes = 0
    end

    # Returns [{ recipient_id:, events: }, ...] with events for a repeated
    # recipient merged in request order, so the relay publishes exactly one
    # envelope per recipient.
    def parse!
      payload = normalize_hash(@payload)
      reject! if payload.blank?

      batches = {}

      normalize_collection(payload[:messages]).each { |message| append!(batches, message) }

      if payload.key?(:recipient_id)
        append!(batches, payload.except(:messages))
      elsif payload.key?(:messages)
        # A messages envelope carrying stray top-level event fields is
        # malformed rather than silently ignored.
        reject! if payload.except(:messages).present?
      end

      reject! if batches.size > max_recipients
      batches.each_value { |events| reject! if events.size > MAX_EVENTS_PER_RECIPIENT }

      batches.map { |recipient_id, events| { recipient_id: recipient_id, events: events } }
    end

    private

    def append!(batches, message)
      message = normalize_hash(message)
      reject! if message.blank?

      recipient_id = validate_recipient_id!(message[:recipient_id])

      events =
        if message.key?(:events)
          reject! if message.except(:recipient_id, :events).present?
          collection = normalize_collection(message[:events])
          reject! if collection.blank?
          collection.map { |event| validate_event!(normalize_hash(event)) }
        else
          [validate_event!(message.except(:recipient_id))]
        end

      (batches[recipient_id] ||= []).concat(events)
    end

    def validate_recipient_id!(raw)
      reject! unless raw.is_a?(Integer) || raw.to_s.match?(/\A\d+\z/)
      recipient_id = raw.to_i
      reject! unless recipient_id.positive?
      recipient_id
    end

    def validate_event!(event)
      reject! unless event.is_a?(Hash)

      type = event[:type]
      reject! if ALLOWED_TYPES.exclude?(type)

      case type
      when "offer", "answer"
        reject! unless event.keys.sort == %i[sdp type]
        sdp = event[:sdp]
        reject! unless sdp.is_a?(String) && sdp.present?
        track_bytes!(sdp.bytesize, MAX_SDP_BYTES)
        { type: type, sdp: sdp }
      when "candidate"
        reject! unless event.keys.sort == %i[candidate type]
        candidate = normalize_hash(event[:candidate])
        reject! if candidate.blank?
        reject! unless (candidate.keys - ALLOWED_CANDIDATE_KEYS).empty?
        candidate.each_value { |value| reject! unless scalar?(value) }
        track_bytes!(candidate.to_json.bytesize, MAX_CANDIDATE_BYTES)
        { type: type, candidate: candidate }
      end
    end

    def track_bytes!(bytes, limit)
      reject! if bytes > limit
      @total_bytes += bytes
      reject! if @total_bytes > MAX_TOTAL_BYTES
    end

    def scalar?(value)
      value.nil? || value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false
    end

    def max_recipients
      [@room.effective_max_participants - 1, MAX_RECIPIENTS].min
    end

    def normalize_hash(value)
      return nil unless value.respond_to?(:to_h)

      hash = value.to_h
      hash.is_a?(Hash) ? hash.symbolize_keys : nil
    rescue TypeError
      nil
    end

    # Form-encoded arrays reach Rails as hashes keyed by numeric strings;
    # numeric ordering (not lexicographic) keeps event order intact past ten
    # elements.
    def normalize_collection(raw)
      return [] if raw.blank?
      return raw if raw.is_a?(Array)

      hash = normalize_hash(raw)
      reject! if hash.nil?
      reject! unless hash.keys.all? { |key| key.to_s.match?(/\A\d+\z/) }
      hash.sort_by { |key, _| key.to_s.to_i }.map { |_, value| value }
    end

    def reject!
      raise Discourse::InvalidParameters.new(I18n.t("voice.errors.invalid_signal"))
    end
  end
end
