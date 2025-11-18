# frozen_string_literal: true

module DiscourseAi
  module Evals
    class ComparisonRunner
      class ComparisonError < StandardError
      end

      SUPPORTED_MODES = {
        "personas" => :personas,
        "persona" => :personas,
        "llms" => :llms,
        "models" => :llms,
      }.freeze

      def initialize(mode:, judge_llm:, output: $stdout)
        @mode = normalize_mode(mode)
        @judge_llm = judge_llm
        @output = output
      end

      def run(eval_cases:, persona_variants:, llms:)
        case mode
        when :personas
          run_persona_comparison(eval_cases, persona_variants, llms)
        when :llms
          run_llm_comparison(eval_cases, persona_variants, llms)
        else
          raise ComparisonError, "Unsupported comparison mode '#{mode}'"
        end
      end

      private

      attr_reader :mode, :judge_llm, :output

      def run_persona_comparison(eval_cases, persona_variants, llms)
        raise ComparisonError, "Persona comparison requires exactly one LLM" if llms.length != 1
        if persona_variants.length < 2
          raise ComparisonError, "Persona comparison needs at least two personas"
        end

        llm = llms.first
        workbenches = persona_variants.map { |variant| [variant, build_workbench(variant)] }

        eval_cases.each do |eval_case|
          candidates = []

          workbenches.each do |variant, workbench|
            payload = nil
            workbench.run(eval_case: eval_case, llms: [llm]) { |result| payload = result }
            unless payload
              output.puts "Skipping persona '#{variant[:key]}' for #{eval_case.id}: missing output."
              next
            end

            candidates << {
              label: variant[:key],
              output: normalize_candidate_output(eval_case, payload[:raw_entries], variant[:key]),
            }
          end

          announce_results(eval_case, candidates, :personas)
        end
      end

      def run_llm_comparison(eval_cases, persona_variants, llms)
        raise ComparisonError, "LLM comparison needs at least two LLM configs" if llms.length < 2
        if persona_variants.length != 1
          raise ComparisonError, "LLM comparison runs against a single persona"
        end

        persona_variant = persona_variants.first
        workbench = build_workbench(persona_variant)

        eval_cases.each do |eval_case|
          candidates = []

          workbench.run(eval_case: eval_case, llms: llms) do |payload|
            candidates << {
              label: payload[:llm_name],
              output:
                normalize_candidate_output(eval_case, payload[:raw_entries], payload[:llm_name]),
            }
          end

          announce_results(eval_case, candidates, :llms, persona_variant[:key])
        end
      end

      def announce_results(eval_case, candidates, mode_label, persona_key = nil)
        if candidates.length < 2
          output.puts "Comparison skipped for #{eval_case.id}: need at least two candidates."
          return
        end

        result = judge_for(eval_case).compare(candidates)

        header = +"=== Comparison (#{mode_label_string(mode_label)}"
        header << ", persona: #{persona_key}" if persona_key && mode_label == :llms
        header << ") #{eval_case.id} ==="
        output.puts
        output.puts header

        if result[:winner].present?
          output.puts "Winner: #{result[:winner]}"
        elsif result[:winner_label].to_s.casecmp("tie").zero?
          output.puts "Result: tie"
        else
          output.puts "Result: no winner reported"
        end
        output.puts "Reason: #{result[:winner_explanation]}" if result[:winner_explanation].present?

        result[:ratings].each do |rating|
          output.puts "  - #{rating[:candidate]}: #{rating[:rating]}/10 — #{rating[:explanation]}"
        end
      end

      def mode_label_string(mode_label)
        case mode_label
        when :personas
          "personas"
        when :llms
          "LLMs"
        else
          mode_label.to_s
        end
      end

      def normalize_candidate_output(eval_case, raw_entries, label)
        entries = Array(raw_entries).compact
        if entries.length != 1
          raise ComparisonError,
                "Eval '#{eval_case.id}' returned #{entries.length} outputs for #{label}, comparison mode requires exactly one."
        end

        entry = entries.first
        value =
          if entry.is_a?(Hash)
            entry[:raw] || entry[:result] || entry[:output]
          else
            entry
          end

        string_value = value.to_s.strip

        if string_value.empty?
          raise ComparisonError, "Eval '#{eval_case.id}' produced an empty output for #{label}."
        end

        string_value
      end

      def build_workbench(variant)
        DiscourseAi::Evals::Workbench.new(
          output: output,
          judge_llm: judge_llm,
          persona_prompt: variant[:prompt],
          persona_label: variant[:key],
        )
      end

      def judge_for(eval_case)
        DiscourseAi::Evals::Judge.new(eval_case: eval_case, judge_llm: judge_llm)
      end

      def normalize_mode(mode)
        normalized = SUPPORTED_MODES[mode.to_s.downcase]
        raise ComparisonError, "Invalid comparison mode '#{mode}'" if normalized.nil?

        normalized
      end
    end
  end
end
