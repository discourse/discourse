# frozen_string_literal: true

module DiscourseWorkflows
  module Simulation
    MODES = %i[pure supported recorded unsupported].freeze

    class SafetyError < StandardError
      attr_reader :reason_key, :params

      def initialize(reason_key, **params)
        @reason_key = reason_key.to_s
        @params = params
        super(I18n.t("discourse_workflows.simulation.#{reason_key}", **params))
      end
    end

    Dispatch =
      Data.define(:item, :item_index, :operation, :config) do
        def json
          item["json"] || {}
        end
      end

    # What a saved test hands a run: outputs captured on earlier runs keyed by
    # "node name:occurrence" then item position, responses an admin pasted keyed
    # by node name, and whether this run should capture what it reads.
    TestData =
      Data.define(:captured_outputs, :pasted_responses, :capture, :checks, :on_complete) do
        def initialize(
          captured_outputs: {},
          pasted_responses: {},
          capture: false,
          checks: [],
          on_complete: nil
        )
          super(
            captured_outputs: (captured_outputs || {}).deep_stringify_keys,
            pasted_responses: (pasted_responses || {}).deep_stringify_keys,
            capture: capture == true,
            checks: WorkflowTestChecks.normalize(checks),
            on_complete:,
          )
        end
      end

    def self.occurrence_key(node_name, occurrence)
      "#{node_name}:#{occurrence}"
    end

    # Digest of a resolved config with run-specific values replaced, so the same
    # request fingerprints identically across runs.
    def self.fingerprint(config, exclude: [], placeholders: {})
      normalized = normalize_for_fingerprint(config.except(*exclude.map(&:to_s)), placeholders)
      Digest::SHA256.hexdigest(JSON.generate(normalized))
    end

    def self.normalize_for_fingerprint(value, placeholders)
      case value
      when Hash
        value.keys.sort.to_h do |key|
          [key.to_s, normalize_for_fingerprint(value[key], placeholders)]
        end
      when Array
        value.map { |entry| normalize_for_fingerprint(entry, placeholders) }
      when String
        placeholders.reduce(value) do |text, (actual, placeholder)|
          actual.present? ? text.gsub(actual.to_s, placeholder) : text
        end
      else
        value
      end
    end

    # Per-run simulation state: the effect log, the records a step would create
    # or change, the instant the run is pinned to, and replay data.
    class RunState
      MAX_EFFECTS = 2_000
      STORED_EFFECTS = 200
      MAX_FIELD_BYTES = 2.kilobytes

      attr_reader :now, :effects, :test, :captures

      def initialize(now: nil, test: nil)
        @now = now || Time.zone.now
        @test = test || TestData.new
        @effects = []
        @captures = {}
        @touched = Set.new
        @synthetic = Set.new
        @next_synthetic_id = -1
      end

      def capture?
        @test.capture
      end

      def recorded_entry(node_name, occurrence, item_index)
        entries = @test.captured_outputs[Simulation.occurrence_key(node_name, occurrence)]
        entries && entries[item_index]
      end

      def pasted_response(node_name)
        @test.pasted_responses[node_name.to_s]
      end

      def capture!(node_name, occurrence, item_index, fingerprint, outputs)
        key = Simulation.occurrence_key(node_name, occurrence)
        @captures[key] ||= []
        @captures[key][item_index] = { "fingerprint" => fingerprint, "outputs" => outputs }
      end

      def record_effect(type, fields, step:, item_index: nil, touches: [])
        raise ArgumentError, "unknown effect type #{type.inspect}" unless Effects.type?(type)
        raise SafetyError.new(:too_many_effects, limit: MAX_EFFECTS) if @effects.size >= MAX_EFFECTS

        @effects << {
          "type" => type.to_s,
          "fields" => fields.deep_stringify_keys,
          "step" => step,
          "item_index" => item_index,
        }
        touches.each { |(record_type, id)| touch(record_type, id) }
        @effects.last
      end

      def touch(record_type, id)
        @touched << [record_type.to_s, id.to_i]
      end

      def touched?(record_type, id)
        @touched.include?([record_type.to_s, id.to_i])
      end

      def synthetic_id(record_type)
        id = @next_synthetic_id
        @next_synthetic_id -= 1
        @synthetic << [record_type.to_s, id]
        id
      end

      def synthetic?(record_type, id)
        @synthetic.include?([record_type.to_s, id.to_i])
      end

      def document(error_kind: nil, failed_step: nil)
        stored = @effects.first(STORED_EFFECTS).map { |effect| bound_effect(effect) }
        truncation = []
        truncation << "effect_count" if @effects.size > STORED_EFFECTS
        truncation << "field_bytes" if stored.any? { |effect| effect["truncated_fields"] }

        {
          "effects" => stored,
          "total_effect_count" => @effects.size,
          "truncation_reasons" => truncation,
          "error_kind" => error_kind,
          "failed_step" => failed_step,
          "pinned_at" => @now.iso8601(6),
          "captures" => @captures,
        }.compact
      end

      private

      def bound_effect(effect)
        truncated = []
        fields =
          effect["fields"].transform_values do |value|
            next value unless value.is_a?(String) && value.bytesize > MAX_FIELD_BYTES

            truncated << value
            value.byteslice(0, MAX_FIELD_BYTES).scrub("")
          end
        bounded = effect.merge("fields" => fields)
        bounded["truncated_fields"] = true if truncated.any?
        bounded
      end
    end

    class Declaration
      attr_reader :modes, :lookups, :fingerprint_excluded

      def initialize(&block)
        @modes = {}
        @lookups = []
        @fingerprint_excluded = []
        @single_mode = nil
        instance_exec(&block) if block
      end

      def pure(*operations)
        declare(:pure, operations)
      end

      def supported(*operations)
        declare(:supported, operations)
      end

      def recorded(*operations)
        declare(:recorded, operations)
      end

      def unsupported(*operations)
        declare(:unsupported, operations)
      end

      def lookup(*operations)
        @lookups.concat(operations.map(&:to_s))
      end

      def fingerprint_except(*keys)
        @fingerprint_excluded.concat(keys.map(&:to_s))
      end

      def mode_for(operation)
        return @single_mode if @single_mode

        mode = @modes[operation.to_s]
        mode == :unsupported ? nil : mode
      end

      def single_mode?
        !@single_mode.nil?
      end

      def declared_operations
        @modes.keys
      end

      def lookup?(operation)
        @lookups.include?(operation.to_s)
      end

      def records?
        @single_mode == :recorded || @modes.value?(:recorded)
      end

      def replays?
        records? || @lookups.any?
      end

      private

      def declare(mode, operations)
        if operations.empty?
          raise ArgumentError, "a node can declare only one operation-less mode" if @single_mode
          @single_mode = mode == :unsupported ? nil : mode
          @single_declared = true
          return
        end

        operations.each do |operation|
          key = operation.to_s
          raise ArgumentError, "#{key} is already classified" if @modes.key?(key)
          @modes[key] = mode
        end
      end
    end
  end
end
