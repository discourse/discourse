#
# This is used for finding the gaps between a subset of elements in an array
# and the original layout. We use this in Discourse to find gaps between posts.
#
# Note that we will only return a gap as 'before' or 'after', not both. We only
# want to display the gap once.
#
class Gaps

  attr_reader :before, :after

  def initialize(subset, original)
    @before = {}
    @after = {}
    @subset = subset
    @original = original

    find_gaps
  end

  def empty?
    @before.size == 0 && @after.size == 0
  end

  def find_gaps
    return if @subset.nil? || @original.nil?

    i = j = 0
    gaps = {}
    current_gap = []

    while
      e1 = @subset[i]
      e2 = @original[j]

      if (e1 == e2)
        if current_gap.size > 0
          @before[e1] = current_gap.dup
          current_gap = []
        end

        i = i + 1
      else
        current_gap << e2
      end
      j = j + 1

      break if (i == @subset.size) || (j == @original.size)
    end

    @after[@subset[i - 1]] = @original[j..-1] if j < @original.size
  end

end
