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
    if @reverse = @m > @n
      @a, @b = @b, @a
      @m, @n = @n, @m
    end
    @is_string = @a.is_a?(String) && @b.is_a?(String)
    if @is_string
      if @a.valid_encoding? && @b.valid_encoding?
        @eq_a = @a.ascii_only? ? @a.bytes : @a.codepoints
        @eq_b = @b.ascii_only? ? @b.bytes : @b.codepoints
      else
        @eq_a = @a.chars
        @eq_b = @b.chars
      end
    else
      intern = {}
      next_id = 0
      @eq_a = @a.map { |el| intern[el] ||= (next_id += 1) }
      @eq_b = @b.map { |el| intern[el] ||= (next_id += 1) }
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

    m = @m
    n = @n
    offset = @offset
    delta = @delta
    eq_a = @eq_a
    eq_b = @eq_b
    budget = @comparison_budget
    used = @comparisons_used

    size = m + n + 3
    fp = Array.new(size, -1)
    path = Array.new(size, -1)
    bt_x = []
    bt_y = []
    bt_prev = []

    p = -1
    delta_offset = delta + offset

    until fp[delta_offset] == n
      p += 1

      k = -p
      while k < delta
        k_off = k + offset
        left_p = fp[k_off - 1] + 1
        right_pp = fp[k_off + 1]
        if left_p > right_pp
          r = path[k_off - 1]
          y = left_p
        else
          r = path[k_off + 1]
          y = right_pp
        end
        x = y - k
        while x < m && y < n
          used += 1
          if used > budget
            @comparisons_used = used
            raise_diff_limit_exceeded!
          end
          break if eq_a[x] != eq_b[y]
          x += 1
          y += 1
        end
        idx = bt_x.size
        path[k_off] = idx
        bt_x << x
        bt_y << y
        bt_prev << r
        fp[k_off] = y
        k += 1
      end

      k = delta + p
      while k > delta
        k_off = k + offset
        left_p = fp[k_off - 1] + 1
        right_pp = fp[k_off + 1]
        if left_p > right_pp
          r = path[k_off - 1]
          y = left_p
        else
          r = path[k_off + 1]
          y = right_pp
        end
        x = y - k
        while x < m && y < n
          used += 1
          if used > budget
            @comparisons_used = used
            raise_diff_limit_exceeded!
          end
          break if eq_a[x] != eq_b[y]
          x += 1
          y += 1
        end
        idx = bt_x.size
        path[k_off] = idx
        bt_x << x
        bt_y << y
        bt_prev << r
        fp[k_off] = y
        k -= 1
      end

      left_p = fp[delta_offset - 1] + 1
      right_pp = fp[delta_offset + 1]
      if left_p > right_pp
        r = path[delta_offset - 1]
        y = left_p
      else
        r = path[delta_offset + 1]
        y = right_pp
      end
      x = y - delta
      while x < m && y < n
        used += 1
        if used > budget
          @comparisons_used = used
          raise_diff_limit_exceeded!
        end
        break if eq_a[x] != eq_b[y]
        x += 1
        y += 1
      end
      idx = bt_x.size
      path[delta_offset] = idx
      bt_x << x
      bt_y << y
      bt_prev << r
      fp[delta_offset] = y
    end

    @comparisons_used = used

    r = path[delta_offset]
    shortest_path = []
    while r != -1
      shortest_path << [bt_x[r], bt_y[r]]
      r = bt_prev[r]
    end
    @shortest_path = shortest_path
  end

  def build_edit_script(shortest_path)
    ses = []
    px, py = 0, 0
    seq_a = @is_string && !@a.ascii_only? ? @a.chars : @a
    seq_b = @is_string && !@b.ascii_only? ? @b.chars : @b
    add_op = @reverse ? :delete : :add
    del_op = @reverse ? :add : :delete

    i = shortest_path.size - 1
    while i >= 0
      sx, sy = shortest_path[i]
      s_diff = sy - sx
      while px < sx || py < sy
        if s_diff > py - px
          ses << [seq_b[py], add_op]
          py += 1
        elsif s_diff < py - px
          ses << [seq_a[px], del_op]
          px += 1
        else
          ses << [seq_a[px], :common]
          px += 1
          py += 1
        end
      end
      i -= 1
    end
    ses
  end

  def build_short_edit_script(shortest_path)
    return build_short_string_edit_script(shortest_path) if @is_string

    ses = []
    px, py = 0, 0
    add_op = @reverse ? :delete : :add
    del_op = @reverse ? :add : :delete

    i = shortest_path.size - 1
    while i >= 0
      sx, sy = shortest_path[i]
      s_diff = sy - sx
      while px < sx || py < sy
        if s_diff > py - px
          if ses.size > 0 && ses[-1][1] == add_op
            ses[-1][0] << @b[py]
          else
            ses << [@b[py], add_op]
          end
          py += 1
        elsif s_diff < py - px
          if ses.size > 0 && ses[-1][1] == del_op
            ses[-1][0] << @a[px]
          else
            ses << [@a[px], del_op]
          end
          px += 1
        else
          if ses.size > 0 && ses[-1][1] == :common
            ses[-1][0] << @a[px]
          else
            ses << [@a[px], :common]
          end
          px += 1
          py += 1
        end
      end
      i -= 1
    end
    ses
  end

  def build_short_string_edit_script(shortest_path)
    ses = []
    px, py = 0, 0
    add_op = @reverse ? :delete : :add
    del_op = @reverse ? :add : :delete

    i = shortest_path.size - 1
    while i >= 0
      sx, sy = shortest_path[i]
      s_diff = sy - sx
      while px < sx || py < sy
        cur_diff = py - px
        if s_diff > cur_diff
          py_end = py + (s_diff - cur_diff)
          py_end = sy if py_end > sy
          chunk = @b[py...py_end]
          if !ses.empty? && ses[-1][1] == add_op
            ses[-1][0] << chunk
          else
            ses << [+chunk, add_op]
          end
          py = py_end
        elsif s_diff < cur_diff
          px_end = px + (cur_diff - s_diff)
          px_end = sx if px_end > sx
          chunk = @a[px...px_end]
          if !ses.empty? && ses[-1][1] == del_op
            ses[-1][0] << chunk
          else
            ses << [+chunk, del_op]
          end
          px = px_end
        else
          rem_x = sx - px
          rem_y = sy - py
          count = rem_x < rem_y ? rem_x : rem_y
          chunk = @a[px, count]
          if !ses.empty? && ses[-1][1] == :common
            ses[-1][0] << chunk
          else
            ses << [+chunk, :common]
          end
          px += count
          py += count
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
