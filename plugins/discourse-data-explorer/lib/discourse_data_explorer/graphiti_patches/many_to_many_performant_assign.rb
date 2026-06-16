# frozen_string_literal: true

module DiscourseDataExplorer
  module GraphitiPatches
    # Performance patch for Graphiti's many_to_many sideload assignment.
    #
    # Stock Graphiti hardcodes `Sideload::ManyToMany#performant_assign?` to
    # false, so loading `include=<many_to_many relationship>` runs an
    # O(parents × children × through-rows) nested scan in `assign_each`.
    # has_many/belongs_to instead build a hash index once, then do O(1)
    # lookups per parent.
    #
    # This restores the indexed path for many_to_many: one pass over each
    # child's through-records, bucketed by parent key, then O(1) per parent →
    # O(children × through + parents). Measured ~4.8x faster / ~5x fewer
    # allocations on a 1000-row `+includes` page (the worst case, where many
    # parents share a child); see docs/api-modernization-exploration.md, Part 8.
    #
    # Upstream candidate, kept plugin-local while the JSON:API direction is
    # still being decided.
    module ManyToManyPerformantAssign
      # Honor the framework default: a custom `assign_each` block opts back out
      # of the indexed path. (Stock ManyToMany ignores this and is always false.)
      def performant_assign?
        !self.class.assign_each_proc
      end

      # Bucket children by the parent key found on each of their through-records,
      # in a single pass. `through`/`true_foreign_key` are hoisted out of the loop.
      def child_map(children)
        through_assoc = through
        parent_key = true_foreign_key
        children.each_with_object({}) do |child, map|
          child
            .public_send(through_assoc)
            .each { |through_record| (map[through_record.public_send(parent_key)] ||= []) << child }
        end
      end

      # Mirror HasMany#children_for, including its String/Integer key coercion
      # (a string parent id should still match integer through-keys, and vice
      # versa).
      def children_for(parent, map)
        pk = parent.public_send(primary_key)
        return map[pk] if map.key?(pk)

        first_key = map.keys.first
        if pk.is_a?(String) && first_key.is_a?(Integer)
          pk = pk.to_i
        elsif pk.is_a?(Integer) && first_key.is_a?(String)
          pk = pk.to_s
        end
        map[pk] || []
      end
    end
  end
end
