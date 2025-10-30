# frozen_string_literal: true

require_relative "recorder"
require_relative "eval"

module DiscourseAi
  module Evals
    # Coordinates the execution of eval cases against one or more LLMs.
    #
    # The Playground drives the orchestration loop: it prepares the Structured
    # Recorder, dispatches work to helpers/utilities based on the eval feature,
    # and feeds the aggregated results back to the Recorder. It intentionally
    # keeps higher-level scripts (`evals/run`) simple while centralizing
    # instrumentation and error handling.
    class Playground
      def initialize(output: $stdout)
        @output = output
      end

      # Iterate through the provided LLM adapters and execute the eval case for
      # each one, recording structured logs along the way.
      #
      # @param eval_case [DiscourseAi::Evals::Eval] the scenario to run.
      # @param llms [Array<#name,#vision?,#llm_model>] LLM wrappers selected by the CLI.
      def run(eval_case:, llms:)
        recorder = Recorder.with_cassette(eval_case, output: output)

        llms.each do |llm|
          start_time = Time.now.utc
          if eval_case.vision && !llm.vision?
            recorder.record_llm_skip(llm.name, "LLM does not support vision")
            next
          end

          results = execute_eval(eval_case, llm)
          recorder.record_llm_results(llm.name, results, start_time)
        rescue DiscourseAi::Evals::Eval::EvalError => e
          recorder.record_llm_results(
            llm.name,
            [{ result: :fail, message: e.message, context: e.context }],
            start_time,
          )
        rescue StandardError => e
          recorder.record_llm_results(llm.name, [{ result: :fail, message: e.message }], start_time)
        end
      ensure
        recorder&.finish
      end

      private

      attr_reader :output

      HELPER_MODES = {
        "ai_helper:proofread" => DiscourseAi::AiHelper::Assistant::PROOFREAD,
        "ai_helper:explain" => DiscourseAi::AiHelper::Assistant::EXPLAIN,
        "ai_helper:smart_dates" => DiscourseAi::AiHelper::Assistant::REPLACE_DATES,
        "ai_helper:title_suggestions" => DiscourseAi::AiHelper::Assistant::GENERATE_TITLES,
        "ai_helper:markdown_tables" => DiscourseAi::AiHelper::Assistant::MARKDOWN_TABLE,
        "ai_helper:custom_prompt" => DiscourseAi::AiHelper::Assistant::CUSTOM_PROMPT,
        "ai_helper:translator" => DiscourseAi::AiHelper::Assistant::TRANSLATE,
        "ai_helper:image_caption" => DiscourseAi::AiHelper::Assistant::IMAGE_CAPTION,
      }.freeze

      def execute_eval(eval_case, llm)
        feature = eval_case.feature

        raw =
          if (helper_mode = helper_mode_for(feature))
            helper_args = eval_case.args
            unless helper_args.is_a?(Hash)
              raise ArgumentError,
                    "Eval '#{eval_case.id}' must define helper args as a hash to use #{feature}"
            end
            helper(llm, helper_mode: helper_mode, **helper_args)
          elsif feature == "custom:pdf_to_text"
            pdf_to_text(llm, **eval_case.args)
          elsif feature == "custom:image_to_text"
            image_to_text(llm, **eval_case.args)
          elsif feature == "custom:prompt"
            DiscourseAi::Evals::PromptEvaluator.new(llm).prompt_call(eval_case.args)
          elsif feature == "custom:edit_artifact"
            edit_artifact(llm, **eval_case.args)
          elsif feature&.start_with?("summarization:")
            summarization(llm, **eval_case.args)
          else
            raise ArgumentError, "Unsupported eval feature '#{feature}'"
          end

        classify_results(eval_case, raw)
      end

      # @param feature [String] fully qualified feature key (module:feature).
      # @return [String, nil] the Assistant mode constant to use for helper runs.
      def helper_mode_for(feature)
        HELPER_MODES[feature]
      end

      def classify_results(eval_case, result)
        if result.is_a?(Array)
          result.each { |r| r.merge!(classify_result(eval_case, r)) }
        else
          [classify_result(eval_case, result)]
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
        prompt = eval_case.judge[:prompt].dup

        if result.is_a?(String)
          prompt.sub!("{{output}}", result)
          eval_case.args.each { |key, value| prompt.sub!("{{#{key}}}", value.to_s) }
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

        judge_llm = DiscourseAi::Evals::Llm.choose(eval_case.judge[:llm]).first

        DiscourseAi::Completions::Prompt.new(
          "You are an expert judge tasked at testing LLM outputs.",
          messages: [{ type: :user, content: prompt }],
        )

        judge_result =
          judge_llm.llm_model.to_llm.generate(prompt, user: Discourse.system_user, temperature: 0)

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

      # Execute an AI Helper prompt for the provided mode, handling optional
      # locale switching and custom prompts used by certain helper features.
      #
      # @param llm [#llm_model] helper-capable LLM wrapper.
      # @param helper_mode [String] Assistant mode constant (see HELPER_MODES).
      # @param input [String] user input for the helper.
      # @param locale [String, nil] optional locale to impersonate during the run.
      # @param extra [Hash] optional keyword args such as :custom_prompt.
      # @return [String] helper suggestion selected for evaluation.
      def helper(llm, helper_mode:, input:, locale: nil, **extra)
        helper = DiscourseAi::AiHelper::Assistant.new(helper_llm: llm.llm_model)
        user = Discourse.system_user

        if locale
          user = User.new
          class << user
            attr_accessor :effective_locale
          end

          user.effective_locale = locale
          user.admin = true
        end

        force_default_locale = extra.fetch(:force_default_locale, false)
        custom_prompt = extra[:custom_prompt]

        result =
          helper.generate_and_send_prompt(
            helper_mode,
            input,
            user,
            force_default_locale: force_default_locale,
            custom_prompt: custom_prompt,
          )

        result[:suggestions].first
      end

      # Extract text from an image upload by delegating to the ImageToText helper.
      #
      # @param llm [#llm_model] LLM wrapper backing the OCR step.
      # @param path [String] path to the source image used for OCR.
      # @return [String] text extracted from the image.
      def image_to_text(llm, path:)
        upload =
          UploadCreator.new(File.open(path), File.basename(path)).create_for(
            Discourse.system_user.id,
          )

        text = +""
        DiscourseAi::Utils::ImageToText
          .new(upload: upload, llm_model: llm.llm_model, user: Discourse.system_user)
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
      # @param llm [#llm_model] LLM wrapper passed to PdfToText for OCR guidance.
      # @param path [String] path to the PDF fixture.
      # @return [String] text aggregated across the PDF pages.
      def pdf_to_text(llm, path:)
        upload =
          UploadCreator.new(File.open(path), File.basename(path)).create_for(
            Discourse.system_user.id,
          )

        text = +""
        DiscourseAi::Utils::PdfToText
          .new(upload: upload, user: Discourse.system_user, llm_model: llm.llm_model)
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
      # @param llm [#llm_model] LLM wrapper used to produce diffs.
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
            llm: llm.llm_model.to_llm,
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

      # Summarize the supplied input by going through the Topic summarization flow.
      #
      # @param llm [#llm_model, #llm_proxy] wrapper providing access to the model.
      # @param input [String] text used to bootstrap the summarization context.
      # @return [String] generated summary text.
      def summarization(llm, input:)
        topic =
          Topic.new(
            category: Category.last,
            title: "Eval topic for topic summarization",
            id: -99,
            user_id: Discourse.system_user.id,
          )
        Post.new(topic: topic, id: -99, user_id: Discourse.system_user.id, raw: input)

        strategy =
          DiscourseAi::Summarization::FoldContent.new(
            llm.llm_proxy,
            DiscourseAi::Summarization::Strategies::TopicSummary.new(topic),
          )

        summary = DiscourseAi::TopicSummarization.new(strategy, Discourse.system_user).summarize
        summary.summarized_text
      end
    end
  end
end
