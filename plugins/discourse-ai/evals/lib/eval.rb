#frozen_string_literal: true

class DiscourseAi::Evals::Eval
  attr_reader :type,
              :path,
              :name,
              :description,
              :id,
              :args,
              :vision,
              :feature,
              :expected_output,
              :expected_output_regex,
              :expected_tool_call,
              :judge

  class EvalError < StandardError
    attr_reader :context

    def initialize(message, context)
      super(message)
      @context = context
    end
  end

  def initialize(path:)
    @yaml = YAML.load_file(path).symbolize_keys
    @path = path
    @name = @yaml[:name]
    @id = @yaml[:id]
    @description = @yaml[:description]
    @vision = @yaml[:vision]
    @type = @yaml[:type]
    @feature = @yaml[:feature]
    if @feature.blank?
      raise ArgumentError, "Eval '#{@id || @name || path}' must define a 'feature' key."
    end
    @expected_output = @yaml[:expected_output]
    @expected_output_regex = @yaml[:expected_output_regex]
    @expected_output_regex =
      Regexp.new(@expected_output_regex, Regexp::MULTILINE) if @expected_output_regex
    @expected_tool_call = @yaml[:expected_tool_call]
    @expected_tool_call.symbolize_keys! if @expected_tool_call
    @judge = @yaml[:judge]
    @judge.symbolize_keys! if @judge
    if @yaml[:args].is_a?(Array)
      @args = @yaml[:args].map(&:symbolize_keys)
    else
      @args = @yaml[:args].symbolize_keys
      @args.each do |key, value|
        if (key.to_s.include?("_path") || key.to_s == "path") && value.is_a?(String)
          @args[key] = File.expand_path(File.join(File.dirname(path), value))
        end
      end
    end
  end

  def run(llm:)
    result =
      case type
      when "helper"
        helper(llm, **args)
      when "pdf_to_text"
        pdf_to_text(llm, **args)
      when "image_to_text"
        image_to_text(llm, **args)
      when "prompt"
        DiscourseAi::Evals::PromptEvaluator.new(llm).prompt_call(args)
      when "edit_artifact"
        edit_artifact(llm, **args)
      when "summarization"
        summarization(llm, **args)
      end

    classify_results(result)
  rescue EvalError => e
    { result: :fail, message: e.message, context: e.context }
  end

  def print
    puts "#{id}: #{description} (feature: #{feature})"
  end

  def to_json
    {
      type: @type,
      path: @path,
      name: @name,
      description: @description,
      id: @id,
      feature: @feature,
      args: @args,
      vision: @vision,
      expected_output: @expected_output,
      expected_output_regex: @expected_output_regex,
    }.compact
  end

  private

  # @param result [String, Array<Hash>] the result of the eval, either
  # "llm response" or [{ result: "llm response", other_attrs: here }]
  # @return [Array<Hash>] an array of hashes with the result classified
  # as pass or fail, along with extra attributes
  def classify_results(result)
    if result.is_a?(Array)
      result.each { |r| r.merge!(classify_result_pass_fail(r)) }
    else
      [classify_result_pass_fail(result)]
    end
  end

  def classify_result_pass_fail(result)
    if expected_output
      if result == expected_output
        { result: :pass }
      else
        { result: :fail, expected_output: expected_output, actual_output: result }
      end
    elsif expected_output_regex
      if result.to_s.match?(expected_output_regex)
        { result: :pass }
      else
        { result: :fail, expected_output: expected_output_regex, actual_output: result }
      end
    elsif expected_tool_call
      tool_call = result

      if result.is_a?(Array)
        tool_call = result.find { |r| r.is_a?(DiscourseAi::Completions::ToolCall) }
      end
      if !tool_call.is_a?(DiscourseAi::Completions::ToolCall) ||
           (tool_call.name != expected_tool_call[:name]) ||
           (tool_call.parameters != expected_tool_call[:params])
        { result: :fail, expected_output: expected_tool_call, actual_output: result }
      else
        { result: :pass }
      end
    elsif judge
      judge_result(result)
    else
      { result: :pass }
    end
  end

  def judge_result(result)
    prompt = judge[:prompt].dup
    if result.is_a?(String)
      prompt.sub!("{{output}}", result)
      args.each { |key, value| prompt.sub!("{{#{key}}}", value.to_s) }
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

    judge_llm = DiscourseAi::Evals::Llm.choose(judge[:llm]).first

    DiscourseAi::Completions::Prompt.new(
      "You are an expert judge tasked at testing LLM outputs.",
      messages: [{ type: :user, content: prompt }],
    )

    result =
      judge_llm.llm_model.to_llm.generate(prompt, user: Discourse.system_user, temperature: 0)

    if rating = result.match(%r{\[RATING\](\d+)\[/RATING\]})
      rating = rating[1].to_i
    end

    if rating.to_i >= judge[:pass_rating]
      { result: :pass }
    else
      {
        result: :fail,
        message: "LLM Rating below threshold, it was #{rating}, expecting #{judge[:pass_rating]}",
        context: result,
      }
    end
  end

  def helper(llm, input:, name:, locale: nil)
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
    result =
      helper.generate_and_send_prompt(name, input, current_user = user, force_default_locale: false)

    result[:suggestions].first
  end

  def image_to_text(llm, path:)
    upload =
      UploadCreator.new(File.open(path), File.basename(path)).create_for(Discourse.system_user.id)

    text = +""
    DiscourseAi::Utils::ImageToText
      .new(upload: upload, llm_model: llm.llm_model, user: Discourse.system_user)
      .extract_text do |chunk, error|
        text << chunk if chunk
        text << "\n\n" if chunk
      end
    text
  ensure
    upload.destroy if upload
  end

  def pdf_to_text(llm, path:)
    upload =
      UploadCreator.new(File.open(path), File.basename(path)).create_for(Discourse.system_user.id)

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
      puts "Eval Errors encountered"
      p diff.failed_searches
      raise EvalError.new("Failed to apply all changes", diff.failed_searches)
    end

    version = artifact.versions.last
    raise EvalError.new("Invalid JS", version.js) if !valid_javascript?(version.js)

    output = { css: version.css, js: version.js, html: version.html }

    artifact.destroy
    output
  end

  def valid_javascript?(str)
    require "open3"

    # Create a temporary file with the JavaScript code
    Tempfile.create(%w[test .js]) do |f|
      f.write(str)
      f.flush

      File.write("/tmp/test.js", str)

      begin
        Discourse::Utils.execute_command(
          "node",
          "--check",
          f.path,
          failure_message: "Invalid JavaScript syntax",
          timeout: 30, # reasonable timeout in seconds
        )
        true
      rescue Discourse::Utils::CommandError
        false
      end
    end
  rescue StandardError
    false
  end

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
