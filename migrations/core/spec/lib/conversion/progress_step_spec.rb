# frozen_string_literal: true

RSpec.describe Migrations::Conversion::ProgressStep do
  def define_step(&block)
    Class.new(described_class, &block)
  end

  describe ".source" do
    it "defines methods on the source role only" do
      step_class =
        define_step do
          source do
            def items
              [1, 2, 3]
            end
          end
        end

      source = step_class.source_class.new
      expect(source.items).to eq([1, 2, 3])

      expect(step_class.new).not_to respond_to(:items)
      expect(step_class.processor_class.new).not_to respond_to(:items)
    end

    it "defines private methods on the source role" do
      step_class =
        define_step do
          source do
            def items
              [build_item]
            end

            private

            def build_item
              :item
            end
          end
        end

      source = step_class.source_class.new
      expect(source.items).to eq([:item])
      expect(source.respond_to?(:build_item)).to be(false)
      expect(source.respond_to?(:build_item, true)).to be(true)
    end

    it "raises an error when called twice" do
      expect do
        define_step do
          source {}
          source {}
        end
      end.to raise_error(ArgumentError, /`source` is already defined/)
    end
  end

  describe ".processor" do
    it "defines methods on the processor role only" do
      step_class =
        define_step do
          processor do
            def process(item)
              item * 2
            end
          end
        end

      processor = step_class.processor_class.new
      expect(processor.process(21)).to eq(42)

      expect(step_class.new).not_to respond_to(:process)
      expect(step_class.source_class.new).not_to respond_to(:process)
    end

    it "defines private methods on the processor role" do
      step_class =
        define_step do
          processor do
            def process(item)
              transform(item)
            end

            private

            def transform(item)
              item.to_s
            end
          end
        end

      processor = step_class.processor_class.new
      expect(processor.process(1)).to eq("1")
      expect(processor.respond_to?(:transform)).to be(false)
      expect(processor.respond_to?(:transform, true)).to be(true)
    end

    it "raises an error when called twice" do
      expect do
        define_step do
          processor {}
          processor {}
        end
      end.to raise_error(ArgumentError, /`processor` is already defined/)
    end
  end

  describe ".helpers" do
    it "mixes the helpers into both roles" do
      step_class =
        define_step do
          helpers do
            def double_it(value)
              value * 2
            end
          end

          source do
            def items
              [double_it(1)]
            end
          end

          processor do
            def process(item)
              double_it(item)
            end
          end
        end

      expect(step_class.source_class.new.items).to eq([2])
      expect(step_class.processor_class.new.process(2)).to eq(4)
    end

    it "works independently of the order of the DSL calls" do
      step_class =
        define_step do
          source do
            def items
              [double_it(1)]
            end
          end

          helpers do
            def double_it(value)
              value * 2
            end
          end
        end

      expect(step_class.source_class.new.items).to eq([2])
    end

    it "raises an error when called twice" do
      expect do
        define_step do
          helpers {}
          helpers {}
        end
      end.to raise_error(ArgumentError, /`helpers` is already defined/)
    end
  end

  describe "role isolation" do
    it "raises a NameError when the processor calls a source method" do
      step_class =
        define_step do
          source do
            def items
              []
            end

            private

            def source_helper
              "source-side state"
            end
          end

          processor do
            def process(item)
              source_helper
            end
          end
        end

      processor = step_class.processor_class.new
      expect { processor.process(1) }.to raise_error(NameError, /source_helper/)
    end

    it "does not expose instance variables set in `items` to the processor" do
      step_class =
        define_step do
          source do
            def items
              @leaked_state = "set in items"
              [1]
            end
          end

          processor do
            def process(item)
              instance_variable_defined?(:@leaked_state)
            end
          end
        end

      step = step_class.new
      step.source.items

      expect(step.create_processor.process(1)).to be(false)
    end

    it "does not capture local variables in methods defined with `def`" do
      local_state = "step-level local"

      step_class =
        define_step do
          source do
            def items
              local_state
            end
          end
        end

      expect { step_class.source_class.new.items }.to raise_error(NameError, /local_state/)
      expect(local_state).to eq("step-level local") # silence the unused variable warning
    end
  end

  describe "role defaults" do
    let(:step_class) { define_step }

    it "uses `nil` as default `max_progress`" do
      expect(step_class.source_class.new.max_progress).to be_nil
    end

    it "raises `NotImplementedError` when `items` is not defined" do
      expect { step_class.source_class.new.items }.to raise_error(NotImplementedError)
    end

    it "raises `NotImplementedError` when `process` is not defined" do
      expect { step_class.processor_class.new.process(1) }.to raise_error(NotImplementedError)
    end

    it "uses a no-op as default `setup`" do
      expect { step_class.processor_class.new.setup }.not_to raise_error
    end
  end

  describe "constant resolution" do
    # The role blocks of real steps are written inside a step class body, so
    # constants in their methods resolve through the step's lexical scope and
    # ancestry (`Step` defines `IntermediateDB` and `Enums`). A `Class.new`
    # block in this spec file would have the wrong lexical scope, hence the
    # string eval.
    before { Object.class_eval <<~RUBY }
        class ProgressStepConstantsFixture < Migrations::Conversion::ProgressStep
          source do
            def items
              [IntermediateDB, Enums]
            end
          end

          processor do
            def process(item)
              [IntermediateDB, Enums]
            end
          end
        end
      RUBY

    after { Object.send(:remove_const, :ProgressStepConstantsFixture) }

    it "resolves `IntermediateDB` and `Enums` inside role blocks via the step's ancestry" do
      expected = [Migrations::Database::IntermediateDB, Migrations::Database::IntermediateDB::Enums]

      expect(ProgressStepConstantsFixture.source_class.new.items).to eq(expected)
      expect(ProgressStepConstantsFixture.processor_class.new.process(nil)).to eq(expected)
    end

    it "does not define the constants on the role classes themselves" do
      expect(ProgressStepConstantsFixture.source_class).not_to have_constant(:IntermediateDB)
      expect(ProgressStepConstantsFixture.processor_class).not_to have_constant(:IntermediateDB)
    end
  end

  describe "#initialize" do
    it "routes args to the role that declares a matching setter" do
      step_class = define_step { source { attr_accessor :source_db } }

      settings = { a: 1 }
      step = step_class.new(settings:, source_db: "source db", unknown_arg: "dropped")

      expect(step.source.settings).to eq(settings)
      expect(step.source.source_db).to eq("source db")

      processor = step.create_processor
      expect(processor.settings).to eq(settings)
      expect(processor).not_to respond_to(:source_db)
      expect(processor).not_to respond_to(:unknown_arg)
    end

    it "keeps no per-step state on the coordinator" do
      step = define_step.new(settings: { a: 1 })

      expect(step).not_to be_a(Migrations::Conversion::Step)
      expect(step).not_to respond_to(:tracker)
      expect(step).not_to respond_to(:step)
      expect(step).not_to respond_to(:settings)
      expect(step).not_to respond_to(:execute)
    end
  end

  describe "#source" do
    it "returns the same source instance every time" do
      step = define_step.new
      expect(step.source).to be(step.source)
    end
  end

  describe "#create_processor" do
    it "creates a new processor with its own tracker on every call" do
      step = define_step.new

      processor1 = step.create_processor
      processor2 = step.create_processor

      expect(processor1).not_to be(processor2)
      expect(processor1.tracker).to be_a(Migrations::Conversion::StepTracker)
      expect(processor1.tracker).not_to be(processor2.tracker)
    end
  end

  describe "step subclasses" do
    it "inherits the roles of the parent step" do
      parent_class =
        define_step do
          source do
            def items
              [1]
            end
          end

          processor do
            def process(item)
              item + 1
            end
          end
        end

      step_class =
        Class.new(parent_class) do
          source do
            def max_progress
              1
            end
          end
        end

      source = step_class.source_class.new
      expect(source.items).to eq([1])
      expect(source.max_progress).to eq(1)
      expect(step_class.processor_class.new.process(1)).to eq(2)
    end
  end

  describe ".run_in_parallel?" do
    it "defaults to false" do
      expect(define_step.run_in_parallel?).to be(false)
    end

    it "returns the configured value" do
      expect(define_step { run_in_parallel true }.run_in_parallel?).to be(true)
      expect(define_step { run_in_parallel false }.run_in_parallel?).to be(false)
    end
  end
end
