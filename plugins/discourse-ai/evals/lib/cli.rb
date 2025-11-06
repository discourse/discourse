# frozen_string_literal: true
require "optparse"
require_relative "features"

class DiscourseAi::Evals::Cli
  class Options
    attr_accessor :eval_name, :model, :list, :list_models, :list_features, :feature_key

    def initialize(
      eval_name: nil,
      model: nil,
      list: false,
      list_models: false,
      list_features: false,
      feature_key: nil
    )
      @eval_name = eval_name
      @model = model
      @list = list
      @list_models = list_models
      @list_features = list_features
      @feature_key = feature_key
    end
  end

  def self.parse_options!(features_registry)
    options = Options.new

    parser =
      OptionParser.new do |opts|
        opts.banner = "Usage: evals/run [options]"

        opts.on("-e", "--eval NAME", "Name of the evaluation to run") do |eval_name|
          options.eval_name = eval_name
        end

        opts.on("--list-models", "List models") { |model| options.list_models = true }
        opts.on("--list-features", "List features available for evals") do
          options.list_features = true
        end

        opts.on(
          "-m",
          "--models NAME",
          "Models to evaluate (will eval all valid models if not specified)",
        ) { |models| options.models = models }

        opts.on("-l", "--list", "List evals") { |model| options.list = true }

        opts.on(
          "-f",
          "--feature KEY",
          "Feature key to evaluate (module_name:feature_name)",
        ) { |key| options.feature_key = key }
      end

    show_help = ARGV.empty?
    parser.parse!

    if show_help
      puts parser
      exit 0
    end

    if options.feature_key && !features_registry.valid_feature_key?(options.feature_key)
      STDERR.puts(
        "Unknown feature '#{options.feature_key}'. Run with --list-features to view valid keys.",
      )
      exit 1
    end

    options
  end
end
