# frozen_string_literal: true

require_relative "recorder"
require_relative "eval"
require_relative "llm_repository"
require_relative "runners/base"
require_relative "runners/ai_helper"
require_relative "runners/translation"
require_relative "runners/hyde"
require_relative "runners/discoveries"
require_relative "runners/inference"
require_relative "runners/spam"
require_relative "runners/summarization"
require_relative "judge"
require_relative "persona_prompt_loader"

module DiscourseAi
  module Evals
    # Coordinates the execution of eval cases against one or more LLMs.
    #
    # The Workbench drives the orchestration loop: it prepares the Structured
    # Recorder, dispatches work to helpers/utilities based on the eval feature,
    # and feeds the aggregated results back to the Recorder. It intentionally
    # keeps higher-level scripts (`evals/run`) simple while centralizing
    # instrumentation and error handling.
    class Workbench
      def initialize(output: $stdout, judge_llm: nil, persona_variants: nil, comparison: nil)
        @output = output
        @judge_llm = judge_llm
        @persona_variants = persona_variants
        @comparison = comparison
      end

      def run_evals(eval_cases:, llms: nil, persona_variants: nil)
        if running_comparisons?
          compare(eval_cases: eval_cases, llms: llms, persona_variants: persona_variants)
        else
          run(eval_cases: eval_cases, llms: llms, persona_variants: persona_variants)
        end
      end

      def compare(eval_cases:, llms:, persona_variants: [{ key: :default, prompt: nil }])
        aggregate_scores = Hash.new { |h, k| h[k] = { passes: 0, evals: eval_cases.length } }

        eval_cases.each do |eval_case|
          recorder = Recorder.with_cassette(eval_case, output: output)
          candidates = []
          persona_compare = persona_variants.length > 1 && llms.length == 1

          persona_variants.each do |variant|
            llms.each do |llm|
              llm_name = llm.display_name || llm.name
              start_time = Time.now.utc

              execution = execute_eval(eval_case, llm, variant, skip_judge: true)
              classified = Array(execution[:classified])

              if classified.first&.dig(:result) == :skipped
                recorder.record_llm_skip(
                  llm_name,
                  classified.first[:message] || "LLM does not support vision",
                )
                next
              end

              recorder.record_llm_results(llm_name, classified, start_time)

              candidates << build_candidate(
                eval_case: eval_case,
                variant: variant,
                llm_name: llm_name,
                execution: execution,
                persona_compare: persona_compare,
              )
            rescue DiscourseAi::Evals::Eval::EvalError => e
              recorder.record_llm_results(
                llm_name,
                [{ result: :fail, message: e.message, context: e.context }],
                start_time,
              )
            rescue StandardError => e
              puts e.backtrace if !Rails.env.test?
              recorder.record_llm_results(
                llm_name,
                [{ result: :fail, message: e.message }],
                start_time,
              )
            end
          end
          update_aggregate_scores(aggregate_scores, candidates)

          announce_comparison(
            recorder,
            eval_case,
            candidates,
            persona_variants.first&.dig(:key),
            aggregate_scores,
          )
        ensure
          recorder&.finish
        end
      end

      def run(eval_cases:, llms:, persona_variants: [{ key: :default, prompt: nil }])
        # We only allow one persona at a time here.
        # If not specified, will contain an element with the default key.
        variant = persona_variants.first

        eval_cases.each do |eval_case|
          recorder = Recorder.with_cassette(eval_case, output: output)

          llms.each do |llm|
            llm_name = llm.display_name || llm.name
            start_time = Time.now.utc

            if eval_case.vision && !llm.vision_enabled?
              recorder.record_llm_skip(llm_name, "LLM does not support vision")
              next
            end

            execution = execute_eval(eval_case, llm, variant)
            classified = Array(execution[:classified])

            if classified.first&.dig(:result) == :skipped
              recorder.record_llm_skip(
                llm_name,
                classified.first[:message] || "LLM does not support vision",
              )
              next
            end

            recorder.record_llm_results(llm_name, classified, start_time)
          rescue DiscourseAi::Evals::Eval::EvalError => e
            recorder.record_llm_results(
              llm_name,
              [{ result: :fail, message: e.message, context: e.context }],
              start_time,
            )
          rescue StandardError => e
            puts e.backtrace if !Rails.env.test?
            recorder.record_llm_results(
              llm_name,
              [{ result: :fail, message: e.message }],
              start_time,
            )
          end
        ensure
          recorder&.finish
        end
      end

      def execute_eval(
        eval_case,
        llm,
        persona_variant = { key: :default, prompt: nil },
        skip_judge: false
      )
        feature = eval_case.feature

        if eval_case.vision && !llm.vision_enabled?
          return(
            {
              raw: nil,
              raw_entries: [],
              classified: [{ result: :skipped, message: "LLM does not support vision" }],
            }
          )
        end

        runner = DiscourseAi::Evals::Runners::Base.find_runner(feature, persona_variant[:prompt])

        raw =
          if runner
            runner.run(eval_case, llm)
          elsif feature == "custom:pdf_to_text"
            pdf_to_text(llm, **eval_case.args)
          elsif feature == "custom:image_to_text"
            image_to_text(llm, **eval_case.args)
          elsif feature == "custom:prompt"
            DiscourseAi::Evals::PromptEvaluator.new(llm).prompt_call(eval_case.args)
          elsif feature == "custom:edit_artifact"
            edit_artifact(llm, **eval_case.args)
          else
            raise ArgumentError, "Unsupported eval feature '#{feature}'"
          end

        entries = normalize_entries(raw)

        {
          raw: raw,
          raw_entries: entries,
          classified: classify_results(eval_case, entries, skip_judge: skip_judge),
        }
      end

      def running_comparisons?
        comparison.present?
      end

      private

      attr_reader :output, :judge_llm, :persona_variants, :comparison

      def normalize_entries(raw)
        raw.is_a?(Array) ? raw : [raw]
      end

      def classify_results(eval_case, entries, skip_judge: false)
        entries.map do |entry|
          raw_value = entry.is_a?(Hash) && entry.key?(:raw) ? entry[:raw] : entry
          metadata = entry.is_a?(Hash) ? entry[:metadata] : nil

          classification = classify_result(eval_case, raw_value, skip_judge: skip_judge)

          classification[:metadata] = metadata if metadata.present?

          classification
        end
      end

      def announce_comparison(recorder, eval_case, candidates, persona_key, aggregate_scores)
        return if candidates.length < 2

        mode_label = comparison_mode_label(persona_key, candidates)

        if judge_llm.present? || eval_case.judge.present?
          judged = judge_for(eval_case).compare(candidates.map { |c| c.slice(:label, :output) })
          recorder.announce_comparison_judged(
            eval_case_id: eval_case.id,
            mode_label: mode_label,
            persona_key: persona_key,
            result: judged,
          )
          recorder.announce_comparison_aggregate(
            mode_label: mode_label,
            persona_key: persona_key,
            aggregate_scores: aggregate_scores,
          )
        else
          failures = []

          candidates.each do |candidate|
            entries = Array(candidate[:classified_entries])
            entries.each do |entry|
              next if entry[:result] == :pass

              failures << {
                label: candidate[:label],
                expected: entry[:expected_output] || entry[:expected_output_regex],
                actual: entry[:actual_output] || entry[:result],
              }
            end
          end

          winner = pick_winner(aggregate_scores)
          status_line = build_status_line(candidates)

          recorder.announce_comparison_expected(
            eval_case_id: eval_case.id,
            mode_label: mode_label,
            persona_key: persona_key,
            winner: winner,
            status_line: status_line,
            failures: failures,
          )
          recorder.announce_comparison_aggregate(
            mode_label: mode_label,
            persona_key: persona_key,
            aggregate_scores: aggregate_scores,
          )
        end
      end

      def pick_winner(aggregate_scores)
        best = aggregate_scores.max_by { |_label, stats| stats[:passes] }&.first
        return :tie if best.nil?

        top_passes = aggregate_scores[best][:passes]
        tied = aggregate_scores.count { |_label, stats| stats[:passes] == top_passes }
        tied > 1 ? :tie : best
      end

      def build_status_line(candidates)
        entries =
          candidates.map do |candidate|
            entries = candidate[:classified_entries]
            emoji = entries.all? { |e| e[:result] == :pass } ? "🟢" : "🔴"
            "#{candidate[:label]} #{emoji}"
          end
        entries.join(" -- ")
      end

      def comparison_mode_label(persona_key, candidates)
        unique_personas = candidates.map { |c| c[:persona_label] }.compact.uniq
        unique_personas.length > 1 ? "personas" : "LLMs"
      end

      def update_aggregate_scores(aggregate_scores, candidates)
        candidates.each do |candidate|
          entries = Array(candidate[:classified_entries])
          pass_eval = entries.all? { |e| e[:result] == :pass }
          # Init score if not present.
          score = aggregate_scores[candidate[:label]][:passes].to_i
          score += 1 if pass_eval
          aggregate_scores[candidate[:label]][:passes] = score
        end
      end

      def build_candidate(eval_case:, variant:, llm_name:, execution:, persona_compare:)
        output =
          normalize_candidate_output(
            eval_case,
            execution[:raw_entries],
            persona_compare ? variant[:key] : llm_name,
          )
        {
          label: persona_compare ? variant[:key] : llm_name,
          persona_label: variant[:key],
          classified_entries: execution[:classified],
          output: output,
        }
      end

      def normalize_candidate_output(eval_case, raw_entries, label)
        entries = Array(raw_entries).compact
        entry = entries.find { |e| value_from_entry(e).present? }
        value = value_from_entry(entry)

        string_value = value.to_s.strip

        raise "Eval '#{eval_case.id}' produced an empty output for #{label}." if string_value.empty?

        string_value
      end

      def value_from_entry(entry)
        return if entry.nil?

        if entry.is_a?(Hash)
          entry[:raw] || entry[:result] || entry[:output]
        else
          entry
        end
      end

      def judge_for(eval_case)
        DiscourseAi::Evals::Judge.new(eval_case: eval_case, judge_llm: judge_llm)
      end

      def classify_result(eval_case, result, skip_judge: false)
        if eval_case.expected_output
          if result == eval_case.expected_output
            { result: :pass }
          else
            { result: :fail, expected_output: eval_case.expected_output, actual_output: result }
          end
        elsif eval_case.expected_output_regex
          if result.to_s.match?(eval_case.expected_output_regex)
            { result: :pass }
          else
            {
              result: :fail,
              expected_output: eval_case.expected_output_regex,
              actual_output: result,
            }
          end
        elsif eval_case.expected_tool_call
          classify_tool_call(eval_case.expected_tool_call, result)
        elsif eval_case.judge && !skip_judge
          judge_result(eval_case, result)
        else
          { result: :pass }
        end
      end

      def classify_tool_call(expected_tool_call, result)
        tool_call = result
        tool_call = result.find { |r| r.is_a?(DiscourseAi::Completions::ToolCall) } if result.is_a?(
          Array,
        )

        if !tool_call.is_a?(DiscourseAi::Completions::ToolCall) ||
             tool_call.name != expected_tool_call[:name] ||
             tool_call.parameters != expected_tool_call[:params]
          { result: :fail, expected_output: expected_tool_call, actual_output: result }
        else
          { result: :pass }
        end
      end

      def print_persona_heading(variant)
        return unless variant[:key]

        label =
          if variant[:key] == DiscourseAi::Evals::PersonaPromptLoader::DEFAULT_PERSONA_KEY
            "default (built-in)"
          else
            variant[:key]
          end

        output.puts "\n=== Persona: #{label} ==="
      end

      def judge_result(eval_case, result)
        if judge_llm.nil?
          raise DiscourseAi::Evals::Eval::EvalError.new(
                  "Evaluation '#{eval_case.id}' requires the --judge option to specify an LLM.",
                  { eval_id: eval_case.id },
                )
        end

        DiscourseAi::Evals::Judge.new(eval_case: eval_case, judge_llm: judge_llm).evaluate(result)
      end

      # Extract text from an image upload by delegating to the ImageToText helper.
      #
      # @param llm [LlmModel] LLM backing the OCR step.
      # @param path [String] path to the source image used for OCR.
      # @return [String] text extracted from the image.
      def image_to_text(llm, path:)
        upload =
          UploadCreator.new(File.open(path), File.basename(path)).create_for(
            Discourse.system_user.id,
          )

        text = +""
        DiscourseAi::Utils::ImageToText
          .new(upload: upload, llm_model: llm, user: Discourse.system_user)
          .extract_text do |chunk, _error|
            text << chunk if chunk
            text << "\n\n" if chunk
          end
        text
      ensure
        upload.destroy if upload
      end

      # Extract text from a PDF, optionally falling back to LLM-guided OCR for pages.
      #
      # @param llm [LlmModel] LLM passed to PdfToText for OCR guidance.
      # @param path [String] path to the PDF fixture.
      # @return [String] text aggregated across the PDF pages.
      def pdf_to_text(llm, path:)
        upload =
          UploadCreator.new(File.open(path), File.basename(path)).create_for(
            Discourse.system_user.id,
          )

        text = +""
        DiscourseAi::Utils::PdfToText
          .new(upload: upload, user: Discourse.system_user, llm_model: llm)
          .extract_text do |chunk|
            text << chunk if chunk
            text << "\n\n" if chunk
          end

        text
      ensure
        upload.destroy if upload
      end

      # Run the edit artifact flow, returning the final artifact contents.
      #
      # @param llm [LlmModel] LLM used to produce diffs.
      # @param css_path [String] path to the CSS fixture.
      # @param js_path [String] path to the JS fixture.
      # @param html_path [String] path to the HTML fixture.
      # @param instructions_path [String] instructions fed to the LLM.
      # @return [Hash] latest artifact snapshot ({ css:, js:, html: }).
      def edit_artifact(llm, css_path:, js_path:, html_path:, instructions_path:)
        css = File.read(css_path)
        js = File.read(js_path)
        html = File.read(html_path)
        instructions = File.read(instructions_path)
        artifact =
          AiArtifact.create!(
            css: css,
            js: js,
            html: html,
            user_id: Discourse.system_user.id,
            post_id: 1,
            name: "eval artifact",
          )

        post = Post.new(topic_id: 1, id: 1)
        diff =
          DiscourseAi::AiBot::ArtifactUpdateStrategies::Diff.new(
            llm: llm.to_llm,
            post: post,
            user: Discourse.system_user,
            artifact: artifact,
            artifact_version: nil,
            instructions: instructions,
          )
        diff.apply

        if diff.failed_searches.present?
          raise DiscourseAi::Evals::Eval::EvalError.new(
                  "Failed to apply all changes",
                  diff.failed_searches,
                )
        end

        version = artifact.versions.last
        unless valid_javascript?(version.js)
          raise DiscourseAi::Evals::Eval::EvalError.new("Invalid JS", version.js)
        end

        output = { css: version.css, js: version.js, html: version.html }

        artifact.destroy
        output
      end

      def valid_javascript?(str)
        require "open3"

        Tempfile.create(%w[test .js]) do |f|
          f.write(str)
          f.flush

          begin
            Discourse::Utils.execute_command(
              "node",
              "--check",
              f.path,
              failure_message: "Invalid JavaScript syntax",
              timeout: 30,
            )
            true
          rescue Discourse::Utils::CommandError
            false
          end
        end
      rescue StandardError
        false
      end
    end
  end
end
