# cf. http://en.wikipedia.org/wiki/Maximum_flow_problem
class MaximumFlow

  # cf. http://en.wikipedia.org/wiki/Push%E2%80%93relabel_maximum_flow_algorithm
  def relabel_to_front(capacities, source, sink)
    n      = capacities.length
    flow   = Array.new(n) { Array.new(n, 0) }
    height = Array.new(n, 0)
    excess = Array.new(n, 0)
    seen   = Array.new(n, 0)
    queue  = (0...n).select { |i| i != source && i != sink }.to_a

    height[source] = n - 1
    excess[source] = Float::INFINITY
    (0...n).each { |v| push(source, v, capacities, flow, excess) }

    p = 0
    while p < queue.length
      u = queue[p]
      h = height[u]
      discharge(u, capacities, flow, excess, seen, height, n)
      if height[u] > h
        queue.unshift(queue.delete_at(p))
        p = 0
      else
        p += 1
      end
    end

    flow[source].reduce(:+)
  end

  private

    def push(u, v, capacities, flow, excess)
      residual_capacity = capacities[u][v] - flow[u][v]
      send = [excess[u], residual_capacity].min
      flow[u][v] += send
      flow[v][u] -= send
      excess[u] -= send
      excess[v] += send
    end

    def discharge(u, capacities, flow, excess, seen, height, n)
      while excess[u] > 0
        if seen[u] < n
          v = seen[u]
          if capacities[u][v] - flow[u][v] > 0 && height[u] > height[v]
            push(u, v, capacities, flow, excess)
          else
            seen[u] += 1
          end
        else
          relabel(u, capacities, flow, height, n)
          seen[u] = 0
        end
      end
    end

    def relabel(u, capacities, flow, height, n)
      min_height = Float::INFINITY
      (0...n).each do |v|
        if capacities[u][v] - flow[u][v] > 0
          min_height = [min_height, height[v]].min
          height[u] = min_height + 1
        end
      end
    end
end
