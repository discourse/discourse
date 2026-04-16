# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class Step
      SUCCESS = "success"
      ERROR = "error"
      WAITING = "waiting"
      FILTERED = "filtered"
      RUNNING = "running"
      SKIPPED = "skipped"

      attr_reader :node_id,
                  :node_name,
                  :node_type,
                  :position,
                  :status,
                  :input,
                  :started_at,
                  :output,
                  :error,
                  :finished_at
      attr_accessor :metadata

      def initialize(
        node_id:,
        node_name:,
        node_type:,
        position:,
        input:,
        status: RUNNING,
        output: nil,
        error: nil,
        started_at: nil,
        finished_at: nil,
        metadata: nil
      )
        @node_id = node_id.to_s
        @node_name = node_name
        @node_type = node_type
        @position = position
        @input = input
        @status = status
        @output = output
        @error = error
        @started_at = started_at || Time.current.iso8601(3)
        @finished_at = finished_at || (status != RUNNING ? @started_at : nil)
        @metadata = metadata
      end

      def success? = status == SUCCESS
      def error? = status == ERROR
      def waiting? = status == WAITING
      def filtered? = status == FILTERED
      def running? = status == RUNNING
      def skipped? = status == SKIPPED

      def succeed!(output:)
        @status = SUCCESS
        @output = output
        @finished_at = Time.current.iso8601(3)
      end

      def filter!(output:)
        @status = FILTERED
        @output = output
        @finished_at = Time.current.iso8601(3)
      end

      def fail!(message)
        @status = ERROR
        @error = message
        @finished_at = Time.current.iso8601(3)
      end

      def mark_waiting!
        @status = WAITING
      end

      def skip!(output:, reason:)
        @status = SKIPPED
        @output = output
        @error = reason
        @finished_at = Time.current.iso8601(3)
      end

      def apply_updates!(updates)
        @status = updates["status"] if updates.key?("status")
        @output = updates["output"] if updates.key?("output")
        @finished_at = updates["finished_at"] if updates.key?("finished_at")
        @error = updates["error"] if updates.key?("error")
      end

      def add_metadata(key, value)
        @metadata ||= {}
        @metadata[key] = value
      end

      def to_h
        h = {
          "node_id" => node_id,
          "node_name" => node_name,
          "node_type" => node_type,
          "position" => position,
          "status" => status,
          "input" => input,
          "started_at" => started_at,
        }
        h["output"] = output if output
        h["finished_at"] = finished_at if finished_at
        h["error"] = error if error
        h["metadata"] = metadata if metadata
        h
      end

      def self.from_h(hash)
        new(
          node_id: hash["node_id"],
          node_name: hash["node_name"],
          node_type: hash["node_type"],
          position: hash["position"] || 0,
          input: hash["input"],
          status: hash["status"] || RUNNING,
          output: hash["output"],
          error: hash["error"],
          started_at: hash["started_at"],
          finished_at: hash["finished_at"],
          metadata: hash["metadata"],
        )
      end

      def self.build(node:, position:, input:, **kwargs)
        new(
          node_id: node.id,
          node_name: node.name,
          node_type: node.type,
          position: position,
          input: input,
          **kwargs,
        )
      end
    end
  end
end
