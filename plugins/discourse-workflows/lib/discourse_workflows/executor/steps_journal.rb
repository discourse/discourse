# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class StepsJournal
      attr_reader :step_position

      def initialize(entries: {}, step_position: 0)
        restore!(entries: entries, step_position: step_position)
      end

      def reset!
        restore!(entries: {}, step_position: 0)
      end

      def restore!(entries:, step_position: nil)
        @entries =
          entries.transform_values { |steps| Array(steps).map { |step| normalize_step(step) } }
        @step_position = step_position.nil? ? total_steps : step_position
      end

      def entries
        @entries.transform_values { |steps| steps.map(&:to_h) }
      end

      def next_step_position
        position = @step_position
        @step_position += 1
        position
      end

      def record_step(node_name, step_data)
        @entries[node_name] ||= []
        @entries[node_name] << normalize_step(step_data)
      end

      def find_step(node_id:, status: nil)
        node_id_str = node_id.to_s
        steps.find { |step| step.node_id == node_id_str && (!status || step.status == status.to_s) }
      end

      def update_step!(node_id:, from_status:, updates:)
        step = find_step(node_id: node_id, status: from_status)
        return if step.nil?

        step.apply_updates!(updates)
        step
      end

      def last_failed_step
        steps.reverse_each.find(&:error?)
      end

      def last_step_with_status(status)
        steps.reverse_each.find { |step| step.status == status.to_s }
      end

      def find_steps_by_type(node_type)
        steps.select { |step| step.node_type == node_type }
      end

      def total_steps
        @entries.values.sum { |node_steps| Array(node_steps).size }
      end

      def steps
        @entries.values.flat_map { |node_steps| Array(node_steps) }
      end

      def serialized_steps_array
        steps.sort_by(&:position).map(&:to_h)
      end

      private

      def normalize_step(step_data)
        step_data.is_a?(Step) ? step_data : Step.from_h(step_data)
      end
    end
  end
end
