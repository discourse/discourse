# frozen_string_literal: true

module Migrations::Importer
  class TopologicalSorter
    def self.sort(classes, skip: [], only: [])
      new(classes, skip:, only:).sort
    end

    def initialize(classes, skip: [], only: [])
      @classes = classes
      @skip = skip
      @only = only
      @filtered_classes = filter_classes
      @dependency_graph = build_dependency_graph
    end

    def sort
      in_degree = Hash.new(0)
      @dependency_graph.each_value { |edges| edges.each { |edge| in_degree[edge] += 1 } }

      queue = @filtered_classes.reject { |cls| in_degree[cls] > 0 }
      result = []

      while queue.any?
        node = queue.shift
        result << node

        @dependency_graph[node].each do |child|
          in_degree[child] -= 1
          queue << child if in_degree[child] == 0
        end
      end

      raise "Circular dependency detected" if result.size < @filtered_classes.size

      result
    end

    private

    def filter_classes
      classes_to_include =
        (
          if @only.empty?
            @classes
          else
            @classes.select { |klass| @only.include?(klass.name.demodulize.underscore) }
          end
        )
      classes_to_include =
        classes_to_include.reject { |klass| @skip.include?(klass.name.demodulize.underscore) }

      with_dependencies = Set.new(classes_to_include)
      classes_to_include.each { |klass| add_dependencies(klass, with_dependencies) }

      with_dependencies.to_a
    end

    def add_dependencies(klass, included_set)
      dependencies = klass.dependencies || []
      dependencies.each do |dependency|
        next if @skip.include?(dependency.name.demodulize.underscore)
        next if included_set.include?(dependency)

        included_set << dependency
        add_dependencies(dependency, included_set)
      end
    end

    def build_dependency_graph
      graph = Hash.new { |hash, key| hash[key] = [] }
      @filtered_classes
        .sort_by(&:to_s)
        .each do |klass|
          dependencies = (klass.dependencies || []).select { |dep| @filtered_classes.include?(dep) }
          dependencies.each { |dependency| graph[dependency] << klass }
          graph[klass] ||= []
        end
      graph
    end
  end
end
