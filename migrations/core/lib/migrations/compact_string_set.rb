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
  # slot too) — on the order of 80-110 MB that every fork ends up copying.
  #
  # Here the names are held as a handful of frozen Strings: the name bytes
  # concatenated into one buffer, their byte offsets packed into another, and an
  # open-addressing probe table of packed 32-bit fingerprints beside them. That
  # is a fixed number of heap slots regardless of the name count; the character,
  # offset and fingerprint bytes sit in malloc space the GC leaves alone.
  #
  # Membership is a hash probe, not a search: `String#hash` picks the slot, the
  # packed fingerprint filters non-members without touching the name bytes
  # (`unpack1` reads an Integer, so a miss allocates nothing), and only a
  # fingerprint hit pays for one `byteslice` to confirm the bytes — membership
  # stays exact, never probabilistic. Forked children inherit the parent's
  # `String#hash` seed, so a table built before fork answers correctly after it.
  #
  # Construction streams: `names` is any Enumerable, consumed once, and
  # duplicates are dropped by the same probe the lookups use — no intermediate
  # sorted array or uniqueness hash, so the build-time peak is just the buffers
  # (plus one exact-size copy of each at the end to shed append slack).
  class CompactStringSet
    # Offsets and probe entries are 32-bit, so the name buffer must stay
    # addressable in 32 bits.
    MAX_TOTAL_BYTES = (2**32) - 1
    private_constant :MAX_TOTAL_BYTES

    # A stored fingerprint of 0 marks an empty probe slot; a real fingerprint
    # that hashes to 0 is nudged to 1. The nudge only widens that fingerprint's
    # filter by one value in four billion — the byte confirm keeps the answer
    # exact either way.
    EMPTY = 0
    private_constant :EMPTY

    # Probe table density. Above this share of filled slots the table doubles;
    # at 50% the expected probe sequence for a miss stays around two slots.
    MAX_LOAD = 0.5
    private_constant :MAX_LOAD

    # @param names [Enumerable<String>] the members; deduped here, consumed once.
    def initialize(names)
      # The buffers grow by appending during the build and are copied to exact
      # size at the end; `capacity:` just seeds them large enough that small
      # sets never reallocate. The name buffer must be UTF-8 (`String.new`
      # defaults to binary): the confirm slices compare against UTF-8 queries,
      # and equal bytes in incompatible encodings are not equal strings.
      @count = 0
      buffer = String.new(capacity: 4096, encoding: Encoding::UTF_8)
      offsets = String.new(capacity: 1024, encoding: Encoding::BINARY)
      offsets << [0].pack("V")

      @capacity = 1024
      @mask = @capacity - 1
      table = empty_table(@capacity)

      names.each do |name|
        # Membership before growth: a duplicate arriving exactly at the
        # threshold must not double the table for nothing (growth rehashes
        # every slot, so it can only happen before the new member's probe).
        next if build_member?(table, buffer, offsets, name)

        table = grow(table, buffer, offsets) if @count >= @capacity * MAX_LOAD
        claim_absent(table, buffer, offsets, name)
      end

      @table = exact_copy(table, Encoding::BINARY)
      @buffer = exact_copy(buffer, Encoding::UTF_8)
      @offsets = exact_copy(offsets, Encoding::BINARY)
    end

    def include?(name)
      hash = name.hash
      fingerprint = fingerprint_for(hash)
      index = hash & @mask

      # `Kernel#loop` allocates per call; the plain `while` keeps a miss
      # allocation-free.
      stored = read32(@table, index * 8)
      while stored != EMPTY
        return true if stored == fingerprint && entry_at(index) == name

        index = (index + 1) & @mask
        stored = read32(@table, index * 8)
      end

      false
    end

    def size
      @count
    end

    def empty?
      @count == 0
    end

    private

    # The slot index comes from the hash's low bits, so the fingerprint takes
    # bits from further up to stay informative within a probe bucket.
    def fingerprint_for(hash)
      fingerprint = (hash >> 27) & 0xffff_ffff
      fingerprint == EMPTY ? 1 : fingerprint
    end

    # A probe slot is 8 packed bytes: the fingerprint, then the member's index
    # into the offsets buffer.
    def slot(table, index)
      [table.unpack1("V", offset: index * 8), table.unpack1("V", offset: index * 8 + 4)]
    end

    def entry_at(probe_index)
      member = read32(@table, probe_index * 8 + 4)
      start = read32(@offsets, member * 4)
      finish = read32(@offsets, (member + 1) * 4)
      @buffer.byteslice(start, finish - start)
    end

    # `unpack1` allocates one object per call, so the probe path assembles its
    # little-endian 32-bit reads from `getbyte`, which allocates nothing.
    def read32(string, byte_offset)
      string.getbyte(byte_offset) | (string.getbyte(byte_offset + 1) << 8) |
        (string.getbyte(byte_offset + 2) << 16) | (string.getbyte(byte_offset + 3) << 24)
    end

    def build_member?(table, buffer, offsets, name)
      hash = name.hash
      fingerprint = fingerprint_for(hash)
      index = hash & @mask

      loop do
        stored, member = slot(table, index)
        return false if stored == EMPTY

        if stored == fingerprint
          start = offsets.unpack1("V", offset: member * 4)
          finish = offsets.unpack1("V", offset: (member + 1) * 4)
          return true if buffer.byteslice(start, finish - start) == name
        end

        index = (index + 1) & @mask
      end
    end

    # Probes to the first empty slot and claims it; the caller established the
    # name is absent, so no equality checks are needed on the way.
    def claim_absent(table, buffer, offsets, name)
      hash = name.hash
      index = hash & @mask
      index = (index + 1) & @mask while slot(table, index).first != EMPTY

      claim(table, index, fingerprint_for(hash), buffer, offsets, name)
    end

    def claim(table, index, fingerprint, buffer, offsets, name)
      position = buffer.bytesize + name.bytesize
      if position > MAX_TOTAL_BYTES
        raise ArgumentError,
              "name bytes exceed the set's 32-bit addressable capacity " \
                "(#{MAX_TOTAL_BYTES} bytes)"
      end

      table.bytesplice(index * 8, 8, [fingerprint, @count].pack("VV"))
      buffer << name
      offsets << [position].pack("V")
      @count += 1
    end

    # Doubles the probe table and re-places every member. The name and offset
    # buffers are already deduplicated and only ever append, so they carry over
    # untouched; only the slots are recomputed.
    def grow(table, buffer, offsets)
      @capacity *= 2
      @mask = @capacity - 1
      grown = empty_table(@capacity)

      each_member(buffer, offsets) do |member, name|
        hash = name.hash
        fingerprint = fingerprint_for(hash)
        index = hash & @mask
        index = (index + 1) & @mask while grown.unpack1("V", offset: index * 8) != EMPTY
        grown.bytesplice(index * 8, 8, [fingerprint, member].pack("VV"))
      end

      grown
    end

    def each_member(buffer, offsets)
      start = 0
      @count.times do |member|
        finish = offsets.unpack1("V", offset: (member + 1) * 4)
        yield member, buffer.byteslice(start, finish - start)
        start = finish
      end
    end

    def empty_table(capacity)
      String.new("\0" * (capacity * 8), encoding: Encoding::BINARY)
    end

    # Appending leaves malloc capacity of roughly twice the content; an
    # exact-capacity copy sheds that slack for the structure's whole lifetime.
    def exact_copy(string, encoding)
      copy = String.new(capacity: string.bytesize, encoding:)
      copy << string
      copy.freeze
    end
  end
end
