# frozen_string_literal: true

module Migrations
  # Class-level dependency metadata for migration steps. Meant to be `extend`ed
  # by a step base class (`Migrations::Importer::Step`,
  # `Migrations::Conversion::Step`); subclasses inherit the macros, and the
  # resulting `dependencies` and `priority` are queryable without instantiating
  # a step. `Migrations::TopologicalSorter` consumes both to order steps.
  #
  # `depends_on` expresses correctness dependencies only -- step B reads what
  # step A wrote -- not thematic grouping. Inventing dependencies needlessly
  # constrains scheduling.
  module StepDependencies
    def self.extended(base)
      base.define_singleton_method(:dependency_base_class) { base }
      base.private_class_method(:dependency_base_class)
    end

    def depends_on(*step_names)
      scope = steps_module
      classes =
        step_names.map do |step_name|
          const_name = step_name.to_s.camelize
          klass = scope.const_get(const_name, false) if scope.const_defined?(const_name, false)

          unless klass.is_a?(Class) && klass < dependency_base_class
            raise NameError,
                  "Step '#{const_name}' (declared via depends_on in #{name}) not found in #{scope}"
          end

          klass
        end

      @dependencies ||= []
      @dependencies.concat(classes)
    end

    def dependencies
      @dependencies || []
    end

    # Among steps whose dependencies are all satisfied, a lower priority value
    # runs first; steps without a priority run last (`Float::INFINITY`), with
    # the class name as the final tie-break. See `Migrations::TopologicalSorter`.

    # stree-ignore
    def priority(value = (getter = true; nil))
      if getter
        @priority
      else
        @priority = value
      end
    end

    private

    # Namespace in which `depends_on` names are resolved. Both frameworks keep
    # sibling steps in the step class's own namespace:
    #   Migrations::Importer::Steps::Users       -> Migrations::Importer::Steps
    #   Migrations::Converters::Discourse::Users -> Migrations::Converters::Discourse
    def steps_module
      name.deconstantize.constantize
    end
  end
end
