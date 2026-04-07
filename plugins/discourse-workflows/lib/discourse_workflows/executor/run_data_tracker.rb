# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class RunDataTracker
      attr_reader :data

      def initialize(data = {})
        @data =
          data.transform_values do |steps|
            Array(steps).map { |s| s.is_a?(Step) ? s : Step.from_h(s) }
          end
      end

      def serializable_data
        @data.transform_values { |steps| steps.map(&:to_h) }
      end

      def record_step(node_name, step_data)
        @data[node_name] ||= []
        @data[node_name] << step_data
      end

      def find_step(node_id:, status: nil)
        node_id_str = node_id.to_s
        @data.each_value do |steps|
          Array(steps).each do |step|
            next if step.node_id != node_id_str
            next if status && step.status != status.to_s
            return step
          end
        end
        nil
      end

      def update_step!(node_id:, from_status:, updates:)
        node_id_str = node_id.to_s
        @data.each_value do |steps|
          Array(steps).each do |step|
            if step.node_id == node_id_str && step.status == from_status.to_s
              step.apply_updates!(updates)
              return step
            end
          end
        end
        nil
      end

      def last_failed_step
        @data.values.flatten.reverse_each.find(&:error?)
      end

      def total_steps
        @data.values.sum { |steps| Array(steps).size }
      end
    end
  end
end
