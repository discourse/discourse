# frozen_string_literal: true
module TestSelection
  class DependencySet
    include Enumerable

    class Registry
      WORD_BITS = 32
      private_constant :WORD_BITS

      def initialize
        @indexes = {}
        @paths = []
        @state_bits = 0
        @mutex = Mutex.new
      end

      def build(paths = [])
        DependencySet.new(registry: self).merge(paths)
      end

      def encode(paths)
        return paths.bits if DependencySet === paths && paths.registry.equal?(self)

        paths.reduce(0) do |bits, path|
          index =
            @indexes[path] ||
              @mutex.synchronize do
                @indexes.fetch(path) do
                  stored = path.frozen? ? path : path.dup.freeze
                  index = @paths.length
                  @paths << stored
                  @state_bits |= 1 << index if stored.start_with?("__state__/")
                  @indexes[stored] = index
                end
              end
          bits | (1 << index)
        end
      end

      def include?(bits:, path:)
        index = @indexes[path]
        !index.nil? && bits[index] == 1
      end

      def state_sources?(bits)
        !(@state_bits & bits).zero?
      end

      def each(bits)
        bits
          .digits(1 << WORD_BITS)
          .each_with_index do |word, index|
            until word.zero?
              first = word & -word
              yield @paths[index * WORD_BITS + first.bit_length - 1]
              word ^= first
            end
          end
      end
    end

    attr_reader :registry, :bits

    def initialize(registry:)
      @registry = registry
      @bits = 0
      @mutex = Mutex.new
    end

    def add(path)
      return self if @registry.include?(bits: @bits, path: path)
      merge([path])
    end

    def merge(paths)
      encoded = @registry.encode(paths)
      @mutex.synchronize { @bits |= encoded }
      self
    end

    def subtract(paths)
      encoded = @registry.encode(paths)
      @mutex.synchronize { @bits &= ~encoded }
      self
    end

    def |(paths)
      dup.merge(paths)
    end

    def -(paths)
      dup.subtract(paths)
    end

    def empty?
      @bits.zero?
    end

    def state_sources?
      @registry.state_sources?(@bits)
    end

    def each
      return enum_for(:each) unless block_given?

      @registry.each(@bits) { |path| yield path }
      self
    end
  end

  private_constant :DependencySet
end
