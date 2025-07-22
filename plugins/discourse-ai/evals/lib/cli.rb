# frozen_string_literal: true
require "optparse"

class DiscourseAi::Evals::Cli
  class Options
    attr_accessor :eval_name, :model, :list, :list_models
    def initialize(eval_name: nil, model: nil, list: false, list_models: false)
      @eval_name = eval_name
      @model = model
      @list = list
      @list_models = list_models
    end
  end

  def self.parse_options!
    options = Options.new

    parser =
      OptionParser.new do |opts|
        opts.banner = "Usage: evals/run [options]"

        opts.on("-e", "--eval NAME", "Name of the evaluation to run") do |eval_name|
          options.eval_name = eval_name
        end

        opts.on("--list-models", "List models") { |model| options.list_models = true }

        opts.on(
          "-m",
          "--model NAME",
          "Model to evaluate (will eval all models if not specified)",
        ) { |model| options.model = model }

        opts.on("-l", "--list", "List evals") { |model| options.list = true }
      end

    show_help = ARGV.empty?
    parser.parse!

    if show_help
      puts parser
      exit 0
    end

    options
  end
end
