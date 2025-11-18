# frozen_string_literal: true

require_relative "features"
require_relative "persona_prompt_loader"

class DiscourseAi::Evals::Cli
  DEFAULT_JUDGE = "gpt-4o"

  attr_reader :persona_keys

  attr_accessor :eval_name,
                :models,
                :list,
                :list_models,
                :list_features,
                :list_personas,
                :feature_key,
                :judge_name,
                :comparison_mode

  def self.parse_options!(features_registry)
    cli = new

    parser =
      OptionParser.new do |opts|
        opts.banner = "Usage: evals/run [options]"

        opts.on("-e", "--eval NAME", "Name of the evaluation to run") do |eval_name|
          cli.eval_name = eval_name
        end

        opts.on("--list-models", "List models") { cli.list_models = true }
        opts.on("--list-features", "List features available for evals") { cli.list_features = true }
        opts.on("--list-personas", "List persona definitions available to evals") do
          cli.list_personas = true
        end

        opts.on(
          "-m",
          "--models NAME",
          "Models to evaluate (comma separated, defaults to all)",
        ) { |models| cli.models = models }

        opts.on("-l", "--list", "List evals") { cli.list = true }

        opts.on(
          "-f",
          "--feature KEY",
          "Feature key to evaluate (module_name:feature_name)",
        ) { |key| cli.feature_key = key }

        opts.on(
          "-j",
          "--judge NAME",
          "LLM config used to judge eval outputs (defaults to gpt-4o when available)",
        ) { |judge| cli.judge_name = judge }

        opts.on(
          "--persona-keys KEYS",
          "Comma-separated list of persona keys to run sequentially",
        ) { |keys| keys.split(",").each { |key| cli.add_persona_key(key) } }

        opts.on("--compare MODE", "Comparison mode (personas or llms)") do |mode|
          cli.comparison_mode = mode
        end
      end

    show_help = ARGV.empty?
    parser.parse!

    if show_help
      puts parser
      exit 0
    end

    if cli.feature_key && !features_registry.valid_feature_key?(cli.feature_key)
      STDERR.puts(
        "Unknown feature '#{cli.feature_key}'. Run with --list-features to view valid keys.",
      )
      exit 1
    end

    if cli.comparison_mode.present?
      normalized = cli.comparison_mode.to_s.downcase.strip
      cli.comparison_mode =
        case normalized
        when "persona", "personas"
          :personas
        when "llms", "models"
          :llms
        else
          STDERR.puts("Unknown comparison mode '#{cli.comparison_mode}'. Use Personas or LLMs.")
          exit 1
        end

      if cli.comparison_mode == :personas
        cli.add_persona_key(DiscourseAi::Evals::PersonaPromptLoader::DEFAULT_PERSONA_KEY)
      end
    end

    cli.judge_name ||= DEFAULT_JUDGE

    cli
  end

  def initialize
    @persona_keys = Set.new
  end

  def judge_provided?
    judge_name.present?
  end

  def add_persona_key(key)
    trimmed = key.to_s.strip
    return if trimmed.empty?

    @persona_keys << trimmed
  end

  def select_evals(available_evals)
    evals = available_evals
    evals = evals.select { |eval_case| eval_case.feature == feature_key } if feature_key.present?
    evals = evals.select { |eval_case| eval_case.id == eval_name } if eval_name.present?

    if evals.empty?
      if feature_key
        puts "Error: No evaluations registered for feature '#{feature_key}'"
      else
        puts "Error: Unknown evaluation '#{eval_name}'"
      end
      exit 1
    end

    evals
  end
end
