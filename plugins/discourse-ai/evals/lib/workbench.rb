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

module DiscourseAi
  module Evals
    # Coordinates the execution of eval cases against one or more LLMs.
    #
    # The Playground drives the orchestration loop: it prepares the Structured
    # Recorder, dispatches work to helpers/utilities based on the eval feature,
    # and feeds the aggregated results back to the Recorder. It intentionally
    # keeps higher-level scripts (`evals/run`) simple while centralizing
    # instrumentation and error handling.
    class Workbench
      def initialize(output: $stdout, judge_llm: nil, persona_prompt: nil)
        @output = output
        @judge_llm = judge_llm
        @persona_prompt = persona_prompt
      end

      # Iterate through the provided LLM adapters and execute the eval case for
      # each one, recording structured logs along the way.
      #
      # @param eval_case [DiscourseAi::Evals::Eval] the scenario to run.
      # @param llms [Array<LlmModel>] LLMs selected by the CLI.
      def run(eval_case:, llms:)
        recorder = Recorder.with_cassette(eval_case, output: output)

        llms.each do |llm|
          llm_name = llm.display_name || llm.name
          start_time = Time.now.utc

          if eval_case.vision && !llm.vision_enabled?
            recorder.record_llm_skip(llm_name, "LLM does not support vision")
            next
          end

          results = execute_eval(eval_case, llm)
          recorder.record_llm_results(llm_name, results, start_time)
        rescue DiscourseAi::Evals::Eval::EvalError => e
          recorder.record_llm_results(
            llm_name,
            [{ result: :fail, message: e.message, context: e.context }],
            start_time,
          )
        rescue StandardError => e
          puts e.backtrace if !Rails.env.test?
          recorder.record_llm_results(llm_name, [{ result: :fail, message: e.message }], start_time)
        end
      ensure
        recorder&.finish
      end

      def execute_eval(eval_case, llm)
        feature = eval_case.feature

        runner = find_runner(feature)
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

        classify_results(eval_case, raw)
      end

      private

      attr_reader :output, :judge_llm, :persona_prompt

      def find_runner(feature)
        DiscourseAi::Evals::Runners::Base.find_runner(feature, persona_prompt)
      end

      def classify_results(eval_case, result)
        entries = result.is_a?(Array) ? result : [result]

        entries.map do |entry|
          raw_value = entry.is_a?(Hash) && entry.key?(:raw) ? entry[:raw] : entry
          metadata = entry.is_a?(Hash) ? entry[:metadata] : nil

          classification = classify_result(eval_case, raw_value)

          classification[:metadata] = metadata if metadata.present?

          classification
        end
      end

      def classify_result(eval_case, result)
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
        elsif eval_case.judge
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

      def judge_result(eval_case, result)
        if judge_llm.nil?
          raise DiscourseAi::Evals::Eval::EvalError.new(
                  "Evaluation '#{eval_case.id}' requires the --judge option to specify an LLM.",
                  { eval_id: eval_case.id },
                )
        end

        prompt = eval_case.judge[:prompt].dup

        if result.is_a?(String)
          prompt.sub!("{{output}}", result)
          eval_case.args.each do |key, value|
            prompt.sub!("{{#{key}}}", format_placeholder_value(value))
          end
        else
          prompt.sub!("{{output}}", result[:result])
          result.each { |key, value| prompt.sub!("{{#{key}}}", value.to_s) }
        end

        prompt += <<~SUFFIX

          Reply with a rating from 1 to 10, where 10 is perfect and 1 is terrible.

          example output:

          [RATING]10[/RATING] perfect output

          example output:

          [RATING]5[/RATING]

          the following failed to preserve... etc...
        SUFFIX

        DiscourseAi::Completions::Prompt.new(
          "You are an expert judge tasked at testing LLM outputs.",
          messages: [{ type: :user, content: prompt }],
        )

        judge_result =
          judge_llm.to_llm.generate(prompt, user: Discourse.system_user, temperature: 0)

        rating_match = judge_result.match(%r{\[RATING\](\d+)\[/RATING\]})
        rating = rating_match ? rating_match[1].to_i : 0

        if rating >= eval_case.judge[:pass_rating]
          { result: :pass }
        else
          {
            result: :fail,
            message:
              "LLM Rating below threshold, it was #{rating}, expecting #{eval_case.judge[:pass_rating]}",
            context: judge_result,
          }
        end
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

      def format_placeholder_value(value)
        case value
        when Array
          value.join("\n\n")
        else
          value.to_s
        end
      end
    end
  end
end
