# frozen_string_literal: true

# Use "An O(NP) Sequence Comparison Algorithm" as described by Sun Wu, Udi Manber and Gene Myers
# in https://publications.mpi-cbg.de/Wu_1990_6334.pdf

class ONPDiff
  class DiffLimitExceeded < StandardError
    attr_reader :comparisons_used, :comparison_budget, :left_size, :right_size

    def initialize(comparisons_used:, comparison_budget:, left_size:, right_size:)
      @comparisons_used = comparisons_used
      @comparison_budget = comparison_budget
      @left_size = left_size
      @right_size = right_size
      super(
        "Diff comparison budget exceeded (used=#{comparisons_used}, budget=#{comparison_budget}, left_size=#{left_size}, right_size=#{right_size})",
      )
    end
  end

  DEFAULT_COMPARISON_BUDGET_FACTOR = 200
  MAX_COMPARISON_BUDGET = 2_000_000

  attr_reader :comparison_budget, :comparisons_used

  def initialize(
    a,
    b,
    comparison_budget_factor: DEFAULT_COMPARISON_BUDGET_FACTOR,
    max_comparison_budget: MAX_COMPARISON_BUDGET
  )
    @a, @b = a, b
    @m, @n = a.size, b.size
    @backtrack = []
    if @reverse = @m > @n
      @a, @b = @b, @a
      @m, @n = @n, @m
    end
    @offset = @m + 1
    @delta = @n - @m
    @comparison_budget = [comparison_budget_factor * (@m + @n), max_comparison_budget].min
    @comparisons_used = 0
  end

  def diff
    @diff ||= build_edit_script(compose)
  end

  def short_diff
    @short_diff ||= build_short_edit_script(compose)
  end

  def paragraph_diff
    @paragraph_diff ||= build_paragraph_edit_script(diff)
  end

  private

  def compose
    return @shortest_path if @shortest_path

    size = @m + @n + 3
    fp = Array.new(size, -1)
    @path = Array.new(size, -1)
    p = -1

    begin
      p += 1

      k = -p
      while k <= @delta - 1
        fp[k + @offset] = snake(k, fp[k - 1 + @offset] + 1, fp[k + 1 + @offset])
        k += 1
      end

      k = @delta + p
      while k >= @delta + 1
        fp[k + @offset] = snake(k, fp[k - 1 + @offset] + 1, fp[k + 1 + @offset])
        k -= 1
      end

      fp[@delta + @offset] = snake(@delta, fp[@delta - 1 + @offset] + 1, fp[@delta + 1 + @offset])
    end until fp[@delta + @offset] == @n

    r = @path[@delta + @offset]

    @shortest_path = []

    while r != -1
      @shortest_path << [@backtrack[r][0], @backtrack[r][1]]
      r = @backtrack[r][2]
    end

    @shortest_path
  end

  def snake(k, p, pp)
    k_offset = k + @offset

    if p > pp
      r = @path[k_offset - 1]
      y = p
    else
      r = @path[k_offset + 1]
      y = pp
    end

    x = y - k

    while x < @m && y < @n
      @comparisons_used += 1
      raise_diff_limit_exceeded! if @comparisons_used > @comparison_budget

      break if @a[x] != @b[y]

      x += 1
      y += 1
    end

    @path[k_offset] = @backtrack.size
    @backtrack << [x, y, r]

    y
  end

  def build_edit_script(shortest_path)
    ses = []
    x, y = 1, 1
    px, py = 0, 0
    i = shortest_path.size - 1
    while i >= 0
      while px < shortest_path[i][0] || py < shortest_path[i][1]
        if shortest_path[i][1] - shortest_path[i][0] > py - px
          t = @reverse ? :delete : :add
          ses << [@b[py], t]
          y += 1
          py += 1
        elsif shortest_path[i][1] - shortest_path[i][0] < py - px
          t = @reverse ? :add : :delete
          ses << [@a[px], t]
          x += 1
          px += 1
        else
          ses << [@a[px], :common]
          x += 1
          y += 1
          px += 1
          py += 1
        end
      end
      i -= 1
    end
    ses
  end

  def build_short_edit_script(shortest_path)
    ses = []
    x, y = 1, 1
    px, py = 0, 0
    i = shortest_path.size - 1
    while i >= 0
      while px < shortest_path[i][0] || py < shortest_path[i][1]
        if shortest_path[i][1] - shortest_path[i][0] > py - px
          t = @reverse ? :delete : :add
          if ses.size > 0 && ses[-1][1] == t
            ses[-1][0] << @b[py]
          else
            ses << [@b[py], t]
          end
          y += 1
          py += 1
        elsif shortest_path[i][1] - shortest_path[i][0] < py - px
          t = @reverse ? :add : :delete
          if ses.size > 0 && ses[-1][1] == t
            ses[-1][0] << @a[px]
          else
            ses << [@a[px], t]
          end
          x += 1
          px += 1
        else
          if ses.size > 0 && ses[-1][1] == :common
            ses[-1][0] << @a[px]
          else
            ses << [@a[px], :common]
          end
          x += 1
          y += 1
          px += 1
          py += 1
        end
      end
      i -= 1
    end
    ses
  end

  def build_paragraph_edit_script(ses)
    paragraph_ses = []
    i = 0
    while i < ses.size
      if ses[i][1] == :common
        paragraph_ses << ses[i]
      else
        if ses[i][1] == :add
          op_code = :add
          opposite_op_code = :delete
        else
          op_code = :delete
          opposite_op_code = :add
        end
        j = i + 1

        j += 1 while j < ses.size && ses[j][1] == op_code

        if j >= ses.size
          paragraph_ses = paragraph_ses.concat(ses[i..j])
          i = j
        else
          k = j
          j -= 1

          k += 1 while k < ses.size && ses[k][1] == opposite_op_code
          k -= 1

          num_before = j - i + 1
          num_after = k - j
          if num_after > 1
            if num_before > num_after
              i2 = i + num_before - num_after
              paragraph_ses = paragraph_ses.concat(ses[i..i2 - 1])
              i = i2
            elsif num_after > num_before
              k -= num_after - num_before
            end
            paragraph_ses = paragraph_ses.concat(pair_paragraphs(ses, i, j))
          else
            paragraph_ses = paragraph_ses.concat(ses[i..k])
          end
          i = k
        end
      end
      i += 1
    end

    paragraph_ses
  end

  def pair_paragraphs(ses, i, j)
    pairs = []
    num_pairs = j - i + 1
    num_pairs.times do
      pairs << ses[i]
      pairs << ses[i + num_pairs]
      i += 1
    end

    pairs
  end

  def raise_diff_limit_exceeded!
    raise DiffLimitExceeded.new(
            comparisons_used: @comparisons_used,
            comparison_budget: @comparison_budget,
            left_size: @m,
            right_size: @n,
          )
  end
end
