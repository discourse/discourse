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
        output.puts "#{llm_name}: "

        results.each do |result|
          if result[:result] == :fail
            output.puts "Failed 🔴"
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
            output.puts "Passed 🟢"
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
    end
  end
end
