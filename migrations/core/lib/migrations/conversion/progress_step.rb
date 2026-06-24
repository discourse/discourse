# frozen_string_literal: true

module Migrations
  module Conversion
    # A step that processes many items and reports progress. It is split into
    # two roles with a hard boundary between them:
    #
    # * `source` enumerates the items (`items`, `max_progress`). It always runs
    #   in the main process.
    # * `processor` handles one item at a time (`process`). It runs in a worker
    #   (a forked process when the step runs in parallel), one instance per
    #   worker. Per-worker state is built in its `setup` hook which runs after
    #   the worker has started, never in the constructor. `setup` must not
    #   create IntermediateDB records — only `process` writes; `setup` runs
    #   under `SetupGuard`, so a write raises `SetupGuard::SetupError` in
    #   serial and parallel mode alike.
    #
    # The roles are separate objects, so state can't leak across the
    # process boundary: a processor method that tries to read source-side
    # state fails with a `NoMethodError` instead of silently seeing stale or
    # missing data. `helpers` is mixed into both roles and is meant for pure
    # functions only (arguments in, value out).
    #
    #   class Users < Conversion::ProgressStep
    #     source do
    #       attr_accessor :source_db
    #
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
    # The blocks are evaluated with `class_eval`, so use plain `def` inside
    # them. Avoid `define_method`: its block closes over the surrounding scope
    # and would smuggle step-level state across the role boundary.
    class ProgressStep < StepBase
      class Source
        include AttributeAssignment

        attr_accessor :settings

        def initialize(args = {})
          assign_attributes(args)
        end

        def max_progress
          nil
        end

        def items
          raise NotImplementedError
        end
      end

      class Processor
        include AttributeAssignment

        attr_accessor :settings
        attr_reader :tracker

        def initialize(args = {})
          @tracker = StepTracker.new
          assign_attributes(args)
        end

        def setup
          # do nothing
        end

        def process(item)
          raise NotImplementedError
        end
      end

      # The step object is only a coordinator: it builds the source (in the
      # main process) and one processor per worker. All per-item state —
      # including the trackers — lives on the roles, and `settings` are routed
      # to them; that's why this class is a sibling of `Step` rather than a
      # subclass — it has no `settings`, `tracker` or `execute` of its own.
      attr_reader :source

      def initialize(args = {})
        @args = args
        @source = self.class.source_class.new(args)
      end

      def create_processor
        self.class.processor_class.new(@args)
      end

      class << self
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

        def run_in_parallel(value)
          @run_in_parallel = !!value
        end

        def run_in_parallel?
          @run_in_parallel == true
        end

        private

        # Steps usually inherit from `ProgressStep` directly and their roles
        # from the `Source`/`Processor` base classes. If a step subclasses
        # another step, its roles subclass the parent step's roles instead.
        def superclass_role(role_method, base_class)
          superclass < ProgressStep ? superclass.public_send(role_method) : base_class
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
