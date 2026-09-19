# frozen_string_literal: true

module Migrations
  class TopologicalSorterError < StandardError
  end

  class TopologicalSorter
    def self.sort(nodes)
      new(nodes).sort
    end

    def initialize(nodes)
      @nodes = nodes
      @dependency_graph = build_dependency_graph
    end

    def sort
      in_degree = Hash.new(0)
      @dependency_graph.each_value { |children| children.each { |child| in_degree[child] += 1 } }

      queue = @nodes.reject { |node| in_degree[node] > 0 }
      sort_queue!(queue)
      sorted = []

      while queue.any?
        node = queue.shift
        sorted << node

        new_ready = []
        @dependency_graph[node].each do |child|
          in_degree[child] -= 1
          new_ready << child if in_degree[child] == 0
        end

        sort_queue!(new_ready)
        queue.concat(new_ready)
      end

      raise TopologicalSorterError, "Circular dependency detected" if sorted.size < @nodes.size

      sorted
    end

    private

    def build_dependency_graph
      graph = Hash.new { |h, k| h[k] = [] }

      @nodes.each do |node|
        if (deps = extract_dependencies(node))
          deps.each { |dep| graph[dep] << node }
        end

        graph[node] ||= []
      end

      graph
    end

    def extract_dependencies(node)
      return nil unless node.respond_to?(:dependencies) && node.dependencies.present?

      missing = node.dependencies.reject { |dep| @nodes.include?(dep) }

      if missing.any?
        missing_class_names = missing.map(&:name).join(", ")
        raise TopologicalSorterError,
              "Node '#{node.name}' has dependencies not in class list: #{missing_class_names}"
      end

      node.dependencies
    end

    def get_priority(node)
      priority = node.priority if node.respond_to?(:priority)
      priority || Float::INFINITY
    end

    def sort_queue!(queue)
      queue.sort_by! { |node| [get_priority(node), node.name] }
    end
  end
end
