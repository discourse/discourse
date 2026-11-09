# frozen_string_literal: true
module TestSelection
  class DependencyGraph
    WORD_BITS = 32
    private_constant :WORD_BITS

    def initialize(serialized: nil, tests: nil)
      @paths = []
      @indexes = {}
      @callers = []
      @tests = {}
      load_serialized(serialized) unless serialized.nil?
      load_tests(tests) unless tests.nil?
    end

    def record(source:, dependencies:)
      source_bit = 1 << intern(source)
      dependencies.each do |dependency|
        index = intern(dependency)
        @callers[index] = row_bits(@callers[index]) | source_bit
      end
      nil
    end

    def record_test(file:, dependencies:)
      raise ArgumentError, "Invalid test name" unless file.is_a?(String) && !file.empty?

      mask = row_bits(@tests.fetch(file, 0))
      dependencies.each { |source| mask |= 1 << intern(source) }
      @tests[file] = mask
      nil
    end

    def encoded_tests
      @tests.transform_values { |mask| encode_row(mask) }
    end

    def merge(serialized:, tests:)
      unless serialized.is_a?(Hash) && tests.is_a?(Hash)
        raise ArgumentError, "Invalid graph fragment"
      end

      incoming = self.class.new(serialized: serialized, tests: tests)
      data = incoming.to_h
      indexes = data.fetch("paths").map { |path| intern(path) }
      data
        .fetch("callers")
        .each_with_index do |encoded, index|
          target = indexes.fetch(index)
          combined = row_bits(@callers.fetch(target))
          each_index(decode_row(encoded)) { |caller| combined |= 1 << indexes.fetch(caller) }
          @callers[target] = combined
        end
      incoming.encoded_tests.each do |file, encoded|
        combined = row_bits(@tests.fetch(file, 0))
        each_index(decode_row(encoded)) { |index| combined |= 1 << indexes.fetch(index) }
        @tests[file] = combined
      end
      nil
    end

    def affected_tests(sources)
      affected = 0
      sources.each do |source|
        index = @indexes[source]
        affected |= 1 << index if index
      end
      @tests.each_with_object({}) do |(file, row), result|
        matches = []
        if row.is_a?(Array)
          row.each { |index| matches << @paths.fetch(index) if affected[index] == 1 }
        else
          each_index(row & affected) { |index| matches << @paths.fetch(index) }
        end
        result[file] = matches unless matches.empty?
      end
    end

    def affected_sources(changes)
      pending = 0
      changes.each do |path|
        index = @indexes[path]
        pending |= 1 << index if index
      end
      affected = pending
      until pending.zero?
        following = 0
        each_index(pending) do |index|
          row = @callers.fetch(index)
          if row.is_a?(Integer)
            following |= row
          else
            row.each { |source| following |= 1 << source }
          end
        end
        pending = following & ~affected
        affected |= pending
      end
      result = []
      each_index(affected) { |index| result << @paths.fetch(index) }
      result
    end

    def to_h
      {
        "version" => 1,
        "paths" => @paths.dup,
        "callers" => @callers.map { |mask| encode_row(mask) },
      }
    end

    def paths
      @paths.dup
    end

    private

    def intern(path)
      raise ArgumentError, "Invalid dependency name" unless path.is_a?(String) && !path.empty?

      @indexes.fetch(path) do
        stored = path.frozen? ? path : path.dup.freeze
        index = @paths.length
        @paths << stored
        @callers << 0
        @indexes[stored] = index
      end
    end

    def row_bits(row)
      return row if row.is_a?(Integer)

      row.reduce(0) { |bits, index| bits | (1 << index) }
    end

    def each_index(mask)
      if mask.is_a?(Array)
        mask.each { |index| yield index }
        return
      end

      offset = 0
      limit = mask.bit_length
      while offset < limit
        word = mask[offset, WORD_BITS]
        until word.zero?
          first = word & -word
          yield offset + first.bit_length - 1
          word ^= first
        end
        offset += WORD_BITS
      end
    end

    def encode_row(mask)
      return mask.dup if mask.is_a?(Array)
      return [] if mask.zero?

      hexadecimal = mask.to_s(16)
      indexes = []
      bytes = 1
      each_index(mask) do |index|
        indexes << index
        bytes += index.to_s.length + 1
        return hexadecimal if bytes > hexadecimal.bytesize + 2
      end
      indexes
    end

    def load_tests(tests)
      raise ArgumentError, "Invalid graph tests" unless tests.is_a?(Hash)

      tests.each do |file, encoded|
        raise ArgumentError, "Invalid test name" unless file.is_a?(String) && !file.empty?
        @tests[file] = decode_row(encoded)
      end
    end

    def load_serialized(serialized)
      unless serialized.is_a?(Hash) && serialized["version"] == 1 &&
               serialized["paths"].is_a?(Array) && serialized["callers"].is_a?(Array) &&
               serialized["paths"].length == serialized["callers"].length &&
               serialized["paths"].uniq == serialized["paths"]
        raise ArgumentError, "Invalid dependency graph"
      end
      serialized.fetch("paths").each { |path| intern(path) }
      serialized
        .fetch("callers")
        .each_with_index { |encoded, index| @callers[index] = decode_row(encoded) }
    end

    def decode_row(encoded)
      if encoded.is_a?(Array)
        previous = -1
        encoded.each do |index|
          unless index.is_a?(Integer) && index > previous && index < @paths.length
            raise ArgumentError, "Invalid dependency index"
          end
          previous = index
        end
        encoded.dup.freeze
      elsif encoded.is_a?(String) && encoded.bytesize <= (@paths.length + 3) / 4 &&
            encoded.match?(/\A[1-9a-f][0-9a-f]*\z/)
        result = encoded.to_i(16)
        raise ArgumentError, "Dependency index outside graph" if result.bit_length > @paths.length
        result
      else
        raise ArgumentError, "Invalid dependency row"
      end
    end
  end
end
