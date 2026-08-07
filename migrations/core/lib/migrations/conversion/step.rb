# frozen_string_literal: true

module Migrations
  module Conversion
    # A step that processes many items and reports progress. It is split into
    # two roles:
    #
    # * `source` enumerates the items (`items`, `max_progress`).
    # * `processor` handles one item at a time (`process`). Per-worker state is
    #   built in its `setup` hook which runs after the worker has started, never
    #   in the constructor. `setup` must not create IntermediateDB records, only
    #   `process` writes; `setup` runs under `SetupGuard`, so a write raises
    #   `SetupGuard::SetupError` whether the step runs inline or in a fork.
    #
    # Both roles run in the worker that processes the step (a forked process, or
    # the main process under `--no-fork`): the worker builds the source, reads its
    # slice of the rows, and feeds each one to a processor. For a partitioned step
    # the parent also builds a source of its own, before forking, only to work out
    # the chunk boundaries.
    #
    # The roles are separate objects, so a processor can't read source-side
    # state: such a call fails with a `NoMethodError`. That keeps `process`
    # from depending on the source's iteration state, which would otherwise be
    # an easy way to write a step that breaks once it's split across forks.
    # `helpers` is mixed into both roles and is meant for pure functions only
    # (arguments in, value out).
    #
    #   class Users < Conversion::Step
    #     source do
    #       def items
    #         @source_db.query("SELECT ...")
    #       end
    #     end
    #
    #     processor do
    #       def setup
    #         @upload_creator = UploadCreator.new
    #       end
    #
    #       def process(item)
    #         IntermediateDB::User.create(...)
    #       end
    #     end
    #   end
    #
    # The blocks are evaluated with `class_eval`, so use plain `def` inside them.
    # Avoid `define_method`: its block closes over the surrounding scope and would
    # leak step-level state across the role boundary.
    class Step
      extend StepDependencies

      IntermediateDB = Database::IntermediateDB
      Enums = Database::IntermediateDB::Enums

      attr_reader :source

      def initialize(args = {})
        @args = args
        @source = self.class.source_class.new(args)
      end

      def create_processor
        self.class.processor_class.new(@args)
      end

      class << self
        def title(
          value = (
            getter = true
            nil
          )
        )
          @title = value unless getter
          @title.presence ||
            I18n.t(
              "converter.default_step_title",
              type: name&.demodulize&.underscore&.humanize(capitalize: false),
            )
        end

        def source(&block)
          raise ArgumentError, "`source` is already defined" if @source_block
          @source_block = block
        end

        def processor(&block)
          raise ArgumentError, "`processor` is already defined" if @processor_block
          @processor_block = block
        end

        def helpers(&block)
          raise ArgumentError, "`helpers` is already defined" if @helpers_block
          @helpers_block = block
        end

        def source_class
          @source_class ||=
            build_role_class(superclass_role(:source_class, Source), :Source, @source_block)
        end

        def partitionable?
          source_class.partitionable?
        end

        def processor_class
          @processor_class ||=
            build_role_class(
              superclass_role(:processor_class, Processor),
              :Processor,
              @processor_block,
            )
        end

        def helpers_module
          @helpers_module ||=
            Module.new.tap { |mod| mod.module_eval(&@helpers_block) if @helpers_block }
        end

        private

        def superclass_role(role_method, base_class)
          superclass < Step ? superclass.public_send(role_method) : base_class
        end

        def build_role_class(base_class, name, block)
          klass = Class.new(base_class)
          const_set(name, klass)
          klass.include(helpers_module)
          klass.class_eval(&block) if block
          klass
        end
      end
    end
  end
end
