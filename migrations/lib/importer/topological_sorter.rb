# frozen_string_literal: true

module Migrations::Importer
  class TopologicalSorter
    def self.sort(classes)
      new(classes).sort
    end

    def initialize(classes)
      @classes = classes
      @dependency_graph = build_dependency_graph
    end

    def sort
      in_degree = Hash.new(0)
      @dependency_graph.each_value { |edges| edges.each { |edge| in_degree[edge] += 1 } }

      queue = @classes.reject { |cls| in_degree[cls] > 0 }
      result = []

      while queue.any?
        node = queue.shift
        result << node

        @dependency_graph[node].each do |child|
          in_degree[child] -= 1
          queue << child if in_degree[child] == 0
        end
      end

      raise "Circular dependency detected" if result.size < @classes.size

      result
    end

    private

    def build_dependency_graph
      graph = Hash.new { |hash, key| hash[key] = [] }
      @classes
        .sort_by(&:to_s)
        .each do |klass|
          dependencies = klass.dependencies || []
          dependencies.each { |dependency| graph[dependency] << klass }
          graph[klass] ||= []
        end
      graph
    end
  end
end
