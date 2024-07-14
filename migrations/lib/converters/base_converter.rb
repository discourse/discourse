# frozen_string_literal: true

module Migrations::Converters
  class BaseConverter
    attr_accessor :settings
    attr_reader :root_path

    def initialize(settings)
      @settings = settings
      @output_db = nil
    end

    def run
      require_all

      if respond_to?(:setup)
        puts "Initializing..."
        setup
      end

      create_database

      steps.each do |step_class|
        step = create_step(step_class)
        before_step_execution(step)

        step.execute

        after_step_execution(step)
      end
    rescue SignalException
      STDERR.puts "\nAborted"
      exit(1)
      # ensure
      # output_db.close if output_db
    end

    def steps
      raise NotImplementedError
    end

    def before_step_execution(step)
      # do nothing
    end

    def after_step_execution(step)
      # do nothing
    end

    def step_args(step_class)
      {}
    end

    private

    def create_database
      # do nothing
    end

    def create_step(step_class)
      default_args = { settings: settings, output_db: @output_db }

      args = default_args.merge(step_args(step_class))
      step_class.new(args)
    end

    def require_all
      Dir[File.join(__dir__, "**", "*.rb")].each { |file| require file }
    end
  end
end
