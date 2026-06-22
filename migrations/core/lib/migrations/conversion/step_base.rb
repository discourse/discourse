# frozen_string_literal: true

module Migrations
  module Conversion
    # Abstract base of all conversion steps; `Base#steps` discovers its
    # subclasses. It carries only what every step kind shares — `Step` adds
    # the imperative single-run contract, `ProgressStep` the per-item
    # source/processor roles.
    class StepBase
      extend StepDependencies

      # These constants also make bare `IntermediateDB::...` / `Enums::...`
      # references work inside `ProgressStep`'s `source` / `processor` blocks:
      # the blocks are written in step class bodies, and constants in methods
      # defined via `class_eval(&block)` resolve through the block's lexical
      # scope — the step class and its ancestors — not the role class.
      IntermediateDB = Database::IntermediateDB
      Enums = Database::IntermediateDB::Enums

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
      end
    end
  end
end
