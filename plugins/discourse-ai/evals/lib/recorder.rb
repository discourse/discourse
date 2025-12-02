# frozen_string_literal: true

require "fileutils"
require "logger"
require_relative "structured_logger"

module DiscourseAi
  module Evals
    class Recorder
      def self.with_cassette(an_eval, persona_key: nil, output: $stdout)
        logs_dir = File.join(__dir__, "../log")
        FileUtils.mkdir_p(logs_dir)

        now = Time.now.strftime("%Y%m%d-%H%M%S")
        normalized_key = normalize_persona_key(persona_key)
        persona_segment = sanitized_persona_key(normalized_key)
        base_filename = [an_eval.id, persona_segment, now].compact.join("-")
        structured_log_filename = "#{base_filename}.json"
        log_filename = "#{base_filename}.log"

        log_path = File.expand_path(File.join(logs_dir, log_filename))
        structured_log_path = File.expand_path(File.join(logs_dir, structured_log_filename))

        logger = Logger.new(File.open(log_path, "a"))
        structured_logger = StructuredLogger.new(structured_log_path)

        new(
          an_eval,
          logger,
          log_path,
          structured_logger,
          persona_key: normalized_key,
          output: output,
        ).tap { |recorder| recorder.running }
      end

      def initialize(an_eval, logger, log_path, structured_logger, persona_key:, output: $stdout)
        @an_eval = an_eval
        @logger = logger
        @log_path = log_path
        @structured_logger = structured_logger
        @output = output
        normalized = persona_key.to_s.strip
        @persona_key = normalized.empty? ? "default" : normalized
      end

      def running
        attach_thread_loggers
        logger.info("Starting evaluation '#{an_eval.id}' (persona: #{persona_key})")
        structured_logger.start_root(
          name: "Evaluating #{an_eval.id} (persona: #{persona_key})",
          args: an_eval.to_json.merge(persona_key: persona_key),
        )
      end

      def record_llm_skip(llm_name, reason)
        if !structured_logger.root_started?
          raise ArgumentError, "You didn't instantiated this object with #with_cassette"
        end
        logger.info("Skipping LLM: #{llm_name} - Reason: #{reason}")
      end

      def record_llm_results(llm_name, results, start_time)
        if !structured_logger.root_started?
          raise ArgumentError, "You didn't instantiated this object with #with_cassette"
        end

        llm_step = structured_logger.add_child_step(name: "Evaluating with LLM: #{llm_name}")

        logger.info("Evaluating with LLM: #{llm_name}")

        results.each do |result|
          if result[:result] == :fail
            output.puts "#{llm_name}: Failed 🔴\n"
            output.puts "Error: #{result[:message]}" if result[:message]
            # this is deliberate, it creates a lot of noise, but sometimes for debugging it's useful
            # output.puts "Context: #{result[:context].to_s[0..2000]}" if result[:context]
            if result[:expected_output] && result[:actual_output]
              output.puts "---- Expected ----\n#{result[:expected_output]}"
              output.puts "---- Actual ----\n#{result[:actual_output]}"
            end
            logger.error("Evaluation failed with LLM: #{llm_name}")
            logger.error("Error: #{result[:message]}") if result[:message]
            logger.error("Expected: #{result[:expected_output]}") if result[:expected_output]
            logger.error("Actual: #{result[:actual_output]}") if result[:actual_output]
            logger.error("Context: #{result[:context]}") if result[:context]
          elsif result[:result] == :pass
            output.puts "#{llm_name}: Passed 🟢"
            logger.info("Evaluation passed with LLM: #{llm_name}")
          else
            STDERR.puts "Error: Unknown result #{an_eval.inspect}"
            logger.error("Unknown result: #{an_eval.inspect}")
          end

          structured_logger.append_entry(
            step: llm_step,
            name: result[:result] == :pass ? :good : :bad,
            started_at: start_time,
            ended_at: Time.now.utc,
          )
        end
      end

      def announce_comparison_judged(eval_case_id:, mode_label:, persona_key: nil, result:)
        step = start_comparison_step(eval_case_id, mode_label, persona_key)

        output.puts
        output.puts "#{comparison_header(eval_case_id, mode_label, persona_key)}\n"
        logger.info(comparison_header(eval_case_id, mode_label, persona_key))

        if result[:winner].present?
          output.puts "Winner: #{result[:winner]}\n"
          logger.info("Winner: #{result[:winner]}")
          append_comparison_entry(step, "winner", result.slice(:winner, :winner_explanation))
        elsif result[:winner_label].to_s.casecmp("tie").zero?
          output.puts "Result: tie\n"
          logger.info("Result: tie")
          append_comparison_entry(step, "winner", result.slice(:winner_label, :winner_explanation))
        else
          output.puts "Result: no winner reported\n"
          logger.info("Result: no winner reported")
          append_comparison_entry(step, "winner", result.slice(:winner_label, :winner_explanation))
        end
        if result[:winner_explanation].present?
          output.puts "Reason: #{result[:winner_explanation]}\n"
        end
        if result[:winner_explanation].present?
          logger.info("Reason: #{result[:winner_explanation]}")
        end

        Array(result[:ratings]).each do |rating|
          output.puts "  - #{rating[:candidate]}: #{rating[:rating]}/10 — #{rating[:explanation]}"
          logger.info("  - #{rating[:candidate]}: #{rating[:rating]}/10 — #{rating[:explanation]}")
          append_comparison_entry(step, "rating", rating)
        end

        finish_comparison_step(step)
      end

      def announce_comparison_expected(
        eval_case_id:,
        mode_label:,
        persona_key: nil,
        winner:,
        status_line: nil,
        failures: []
      )
        step = start_comparison_step(eval_case_id, mode_label, persona_key)

        output.puts
        output.puts comparison_header(eval_case_id, mode_label, persona_key)
        logger.info(comparison_header(eval_case_id, mode_label, persona_key))

        if winner == :tie
          output.puts "Result: tie\n"
          logger.info("Result: tie")
          append_comparison_entry(step, "winner", winner: "tie")
        else
          output.puts "Winner: #{winner}\n"
          logger.info("Winner: #{winner}")
          append_comparison_entry(step, "winner", winner: winner)
        end

        output.puts "  #{status_line}" if status_line.present?
        logger.info("  #{status_line}") if status_line.present?
        append_comparison_entry(step, "status", status_line: status_line) if status_line.present?

        failures.each do |failure|
          output.puts "      #{failure[:label]} expected: #{failure[:expected].inspect}, actual: #{failure[:actual].inspect}"
          logger.info(
            "      #{failure[:label]} expected: #{failure[:expected].inspect}, actual: #{failure[:actual].inspect}",
          )
          append_comparison_entry(step, "failure", failure)
        end

        finish_comparison_step(step)
      end

      def announce_comparison_aggregate(mode_label:, persona_key: nil, aggregate_scores:)
        return if aggregate_scores.blank?

        step = start_comparison_step(nil, mode_label, persona_key, summary: true)

        output.puts
        output.puts "#{comparison_header(nil, mode_label, persona_key, summary: true)}\n"
        logger.info(comparison_header(nil, mode_label, persona_key, summary: true))

        aggregate_scores.each do |label, stats|
          output.puts "  - #{label}: #{stats[:passes]}/#{stats[:evals]} passed"
          logger.info("  - #{label}: #{stats[:passes]}/#{stats[:evals]} passed")
          append_comparison_entry(
            step,
            "aggregate",
            label: label,
            passes: stats[:passes],
            evals: stats[:evals],
          )
        end

        finish_comparison_step(step)
      end

      def finish
        structured_logger.finish_root(end_time: Time.now.utc)

        detach_thread_loggers

        structured_logger.save

        output.puts
        output.puts "Log file: #{log_path}"
        output.puts "Structured log file (ui.perfetto.dev): #{structured_logger.path}"
      ensure
        logger&.close
      end

      private

      attr_reader :an_eval, :logger, :structured_logger, :output, :log_path, :persona_key

      def self.normalize_persona_key(key)
        stripped = key.to_s.strip
        stripped = "default" if stripped.empty?
        stripped
      end

      def self.sanitized_persona_key(key)
        stripped = key.to_s.strip
        stripped = "default" if stripped.empty?

        slug = stripped.gsub(/[^a-zA-Z0-9]+/, "-").gsub(/-+/, "-").gsub(/^-|-$/, "")
        slug.empty? ? "default" : slug.downcase
      end

      def attach_thread_loggers
        @previous_thread_loggers = {
          audit_log: Thread.current[:llm_audit_log],
          structured_log: Thread.current[:llm_audit_structured_log],
        }

        Thread.current[:llm_audit_log] = logger
        Thread.current[:llm_audit_structured_log] = structured_logger
      end

      def detach_thread_loggers
        Thread.current[:llm_audit_log] = @previous_thread_loggers[:audit_log]
        Thread.current[:llm_audit_structured_log] = @previous_thread_loggers[:structured_log]
      end

      def comparison_header(eval_case_id, mode_label, persona_key, summary: false)
        header = "=== Comparison (#{mode_label}"
        header << ", persona: #{persona_key}" if persona_key
        header << ")"
        header << " #{eval_case_id}" if eval_case_id && !summary
        header
      end

      def start_comparison_step(eval_case_id, mode_label, persona_key, summary: false)
        ensure_root!
        name = "Comparison (#{mode_label}"
        name += ", persona: #{persona_key}" if persona_key
        name += ")"
        name += " #{eval_case_id}" if eval_case_id && !summary
        structured_logger.add_child_step(name: name)
      end

      def finish_comparison_step(step)
        step[:end_time] = Time.now.utc if step && step[:end_time].nil?
      end

      def append_comparison_entry(step, name, args)
        structured_logger.append_entry(step: step, name: name, args: args, started_at: Time.now.utc)
      end

      def ensure_root!
        unless structured_logger.root_started?
          raise ArgumentError, "Structured logger root not started"
        end
      end
    end
  end
end
