# frozen_string_literal: true

module Migrations
  # An immutable membership set for a large number of short strings (usernames,
  # tag names) whose bulk lives in malloc'd buffers the GC never writes into, so
  # it stays copy-on-write-stable across forks no matter when it is built.
  #
  # A step's args are built after the scheduler's one-time `Process.warmup`, so
  # their objects are still young when the step's workers fork. Ruby's
  # generational GC then stamps age bits into every live object's slot during the
  # children's early GC cycles, and that write privatizes the copy-on-write page
  # the slot sits on. A `Set` of a million usernames is a million such slots
  # (names of 23 bytes or fewer are embedded, so their characters live in the
  # slot too) — on the order of 80-110 MB that silently unshares per fork.
  #
  # Here the names are held as just two frozen Strings: all of them sorted and
  # concatenated into one buffer, plus their byte offsets packed into another.
  # That is two heap slots regardless of the name count; the character and offset
  # bytes sit in malloc space the GC leaves alone. Roughly 16-20 MB per million
  # names — about 5x smaller than the equivalent Set, and indifferent to when it
  # is built relative to `Process.warmup`.
  #
  # Membership is a binary search. The build-time sort (`Array#sort`) and the
  # query-time comparison (`String#<=>`) are both bytewise, and every name is
  # UTF-8 (callers normalize upstream), where bytewise order equals codepoint
  # order, so the two orderings agree. Do not swap in `casecmp` or any
  # locale-aware comparison — that would break the invariant the search relies on.
  # This class stores bytes; normalization is the caller's job.
  class SortedStringSet
    # @param names [Enumerable<String>] the members; deduped and sorted here.
    def initialize(names)
      sorted = names.to_a.uniq
      sorted.sort!
      @count = sorted.size

      # Both buffers are allocated at their final size up front: growing them by
      # appending would leave the usual doubling slack — malloc capacity of
      # roughly twice the content — retained for the structure's whole lifetime.
      # The buffer must be UTF-8 (`String.new` defaults to binary): `entry` slices
      # compare against UTF-8 queries, and equal bytes in incompatible encodings
      # are not equal strings.
      total = sorted.sum(&:bytesize)
      buffer = String.new(capacity: total, encoding: Encoding::UTF_8)
      offsets = String.new(capacity: (@count + 1) * 4, encoding: Encoding::BINARY)

      position = 0
      offsets << [0].pack("V")

      sorted.each do |name|
        buffer << name
        position += name.bytesize
        offsets << [position].pack("V")
      end

      @buffer = buffer.freeze
      @offsets = offsets.freeze
    end

    def include?(name)
      low = 0
      high = @count - 1

      while low <= high
        mid = (low + high) / 2
        comparison = entry(mid) <=> name

        if comparison < 0
          low = mid + 1
        elsif comparison > 0
          high = mid - 1
        else
          return true
        end
      end

      false
    end

    def size
      @count
    end

    def empty?
      @count.zero?
    end

    private

    # The i-th name, sliced back out of the buffer using the offsets that bound it.
    def entry(index)
      start = @offsets.unpack1("V", offset: index * 4)
      finish = @offsets.unpack1("V", offset: (index + 1) * 4)
      @buffer.byteslice(start, finish - start)
    end
  end
end
