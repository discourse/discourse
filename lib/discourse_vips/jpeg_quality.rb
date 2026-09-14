# frozen_string_literal: true

module DiscourseVips
  module JpegQuality
    class Error < StandardError
    end

    class InvalidJPEG < Error
    end

    Estimate =
      Struct.new(
        :status,
        :quality,
        :deviation,
        :table_count,
        :precisions,
        :reason,
        keyword_init: true,
      ) do
        def exact?
          status == :exact
        end

        def approximate?
          status == :approximate
        end

        def unknown?
          status == :unknown
        end
      end

    QuantizationTable = Struct.new(:id, :precision, :values, keyword_init: true)
    ParsedJPEG = Struct.new(:tables, :used_table_ids, :lossless, keyword_init: true)

    class Parser
      TEM = 0x01
      DQT = 0xDB
      EOI = 0xD9
      SOS = 0xDA

      SOF_MARKERS = [
        0xC0,
        0xC1,
        0xC2,
        0xC3,
        0xC5,
        0xC6,
        0xC7,
        0xC9,
        0xCA,
        0xCB,
        0xCD,
        0xCE,
        0xCF,
      ].freeze
      LOSSLESS_SOF_MARKERS = [0xC3, 0xC7, 0xCB, 0xCF].freeze
      STANDALONE_MARKERS = ([0xD8, 0xD9] + (0xD0..0xD7).to_a).freeze
      DISCARD_CHUNK_SIZE = 16 * 1024
      MAX_HEADER_BYTES = 16 * 1024 * 1024

      def initialize(io)
        @io = io
        @tables = {}
        @used_table_ids = []
        @lossless = false
        @header_bytes = 0
        @frame_seen = false
      end

      def parse
        @io.binmode if @io.respond_to?(:binmode)
        unless read_exact(2, "truncated JPEG") == "\xFF\xD8".b
          raise InvalidJPEG, "missing JPEG SOI marker"
        end

        loop do
          marker = read_marker

          case marker
          when TEM
            next
          when DQT
            parse_dqt(read_segment(marker))
          when *SOF_MARKERS
            parse_sof(marker, read_segment(marker))
          when SOS
            parse_sos(read_segment(marker))
            break
          when EOI
            raise InvalidJPEG, "JPEG ended before its first scan"
          else
            if STANDALONE_MARKERS.include?(marker)
              raise InvalidJPEG,
                    format("unexpected standalone marker FF%02X before first scan", marker)
            end
            raise InvalidJPEG, format("unsupported reserved marker FF%02X", marker) if marker < 0xC0

            discard_segment(marker)
          end
        end

        ParsedJPEG.new(tables: @tables, used_table_ids: @used_table_ids.uniq, lossless: @lossless)
      end

      private

      def discard_segment(marker)
        remaining = segment_payload_length(marker)

        while remaining.positive?
          length = [remaining, DISCARD_CHUNK_SIZE].min
          read_exact(length, marker_error(marker, "payload"))
          remaining -= length
        end
      end

      def marker_error(marker, part)
        format("truncated FF%02X marker %s", marker, part)
      end

      def parse_dqt(payload)
        raise InvalidJPEG, "empty DQT marker" if payload.empty?

        offset = 0

        while offset < payload.bytesize
          descriptor = payload.getbyte(offset)
          offset += 1
          precision_code = descriptor >> 4
          table_id = descriptor & 0x0F

          raise InvalidJPEG, "invalid DQT precision #{precision_code}" if precision_code > 1
          raise InvalidJPEG, "invalid DQT table id #{table_id}" if table_id > 3

          precision = precision_code.zero? ? 8 : 16
          value_size = precision / 8
          table_size = 64 * value_size
          if payload.bytesize - offset < table_size
            raise InvalidJPEG, "truncated DQT table #{table_id}"
          end

          values =
            if precision == 8
              payload.byteslice(offset, table_size).bytes
            else
              64.times.map do |index|
                value_offset = offset + (index * 2)
                (payload.getbyte(value_offset) << 8) | payload.getbyte(value_offset + 1)
              end
            end

          if values.include?(0)
            raise InvalidJPEG, "DQT table #{table_id} contains a zero coefficient"
          end

          @tables[table_id] = QuantizationTable.new(
            id: table_id,
            precision: precision,
            values: values.freeze,
          )
          offset += table_size
        end
      end

      def parse_sof(marker, payload)
        raise InvalidJPEG, "multiple frame headers before first scan" if @frame_seen
        @frame_seen = true
        raise InvalidJPEG, format("truncated FF%02X frame header", marker) if payload.bytesize < 6

        component_count = payload.getbyte(5)
        expected_size = 6 + (component_count * 3)
        unless component_count.positive? && payload.bytesize == expected_size
          raise InvalidJPEG, format("invalid FF%02X frame header length", marker)
        end

        component_count.times do |index|
          table_id = payload.getbyte(8 + (index * 3))
          raise InvalidJPEG, "invalid frame DQT table id #{table_id}" if table_id > 3

          next if @used_table_ids.include?(table_id)

          @used_table_ids << table_id
        end

        @lossless ||= LOSSLESS_SOF_MARKERS.include?(marker)
      end

      def parse_sos(payload)
        raise InvalidJPEG, "scan precedes frame header" if @used_table_ids.empty?
        raise InvalidJPEG, "truncated scan header" if payload.empty?

        component_count = payload.getbyte(0)
        expected_size = 1 + (component_count * 2) + 3
        unless component_count.positive? && payload.bytesize == expected_size
          raise InvalidJPEG, "invalid scan header length"
        end
      end

      def read_exact(length, error_message)
        @header_bytes += length
        raise InvalidJPEG, "JPEG header exceeds size limit" if @header_bytes > MAX_HEADER_BYTES

        result = +"".b

        while result.bytesize < length
          chunk = @io.read(length - result.bytesize)
          raise InvalidJPEG, error_message if chunk.nil? || chunk.empty?

          result << chunk
        end

        result
      end

      def read_marker
        prefix = read_exact(1, "truncated JPEG before first scan").getbyte(0)
        raise InvalidJPEG, format("expected marker prefix, got %02X", prefix) unless prefix == 0xFF

        marker = read_exact(1, "truncated JPEG marker").getbyte(0)
        marker = read_exact(1, "truncated JPEG marker").getbyte(0) while marker == 0xFF
        raise InvalidJPEG, "unexpected stuffed byte outside image data" if marker.zero?

        marker
      end

      def read_segment(marker)
        read_exact(segment_payload_length(marker), marker_error(marker, "payload"))
      end

      def segment_payload_length(marker)
        bytes = read_exact(2, marker_error(marker, "length"))
        length = (bytes.getbyte(0) << 8) | bytes.getbyte(1)
        raise InvalidJPEG, format("invalid FF%02X marker length %d", marker, length) if length < 2

        length - 2
      end
    end

    class Estimator
      LUMINANCE_BASE = [
        16,
        11,
        10,
        16,
        24,
        40,
        51,
        61,
        12,
        12,
        14,
        19,
        26,
        58,
        60,
        55,
        14,
        13,
        16,
        24,
        40,
        57,
        69,
        56,
        14,
        17,
        22,
        29,
        51,
        87,
        80,
        62,
        18,
        22,
        37,
        56,
        68,
        109,
        103,
        77,
        24,
        35,
        55,
        64,
        81,
        104,
        113,
        92,
        49,
        64,
        78,
        87,
        103,
        121,
        120,
        101,
        72,
        92,
        95,
        98,
        112,
        100,
        103,
        99,
      ].freeze

      CHROMINANCE_BASE = [
        17,
        18,
        24,
        47,
        99,
        99,
        99,
        99,
        18,
        21,
        26,
        66,
        99,
        99,
        99,
        99,
        24,
        26,
        56,
        99,
        99,
        99,
        99,
        99,
        47,
        66,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
        99,
      ].freeze

      ZIGZAG_ORDER = [
        0,
        1,
        8,
        16,
        9,
        2,
        3,
        10,
        17,
        24,
        32,
        25,
        18,
        11,
        4,
        5,
        12,
        19,
        26,
        33,
        40,
        48,
        41,
        34,
        27,
        20,
        13,
        6,
        7,
        14,
        21,
        28,
        35,
        42,
        49,
        56,
        57,
        50,
        43,
        36,
        29,
        22,
        15,
        23,
        30,
        37,
        44,
        51,
        58,
        59,
        52,
        45,
        38,
        31,
        39,
        46,
        53,
        60,
        61,
        54,
        47,
        55,
        62,
        63,
      ].freeze

      BASE_TABLES = [LUMINANCE_BASE, CHROMINANCE_BASE].freeze
      MAX_APPROXIMATE_LOG_RMSE = Math.log(1.20)

      CANDIDATE_TABLES =
        (1..100)
          .to_h do |quality|
            scale = quality < 50 ? 5000 / quality : 200 - quality * 2
            candidates =
              BASE_TABLES.flat_map do |base|
                [255, 32_767].map do |maximum|
                  natural =
                    base.map { |coefficient| ((coefficient * scale + 50) / 100).clamp(1, maximum) }
                  ZIGZAG_ORDER.map { |index| natural[index] }.freeze
                end
              end
            [quality, candidates.uniq.freeze]
          end
          .freeze
      private_constant :CANDIDATE_TABLES

      EXACT_QUALITIES =
        CANDIDATE_TABLES
          .each_with_object({}) do |(quality, candidates), index|
            candidates.each { |candidate| (index[candidate] ||= []) << quality }
          end
          .transform_values(&:freeze)
          .freeze
      private_constant :EXACT_QUALITIES

      def initialize(parsed_jpeg)
        @parsed_jpeg = parsed_jpeg
      end

      def estimate
        return unknown("lossless JPEG processes do not use DQT quality") if @parsed_jpeg.lossless

        tables = active_tables
        return unknown("no DQT tables were found before the first scan") if tables.empty?

        missing_ids = @parsed_jpeg.used_table_ids - @parsed_jpeg.tables.keys
        unless missing_ids.empty?
          return(
            unknown(
              "frame references undefined DQT table#{"s" if missing_ids.length > 1} #{missing_ids.join(", ")}",
            )
          )
        end

        exact_quality =
          tables.map { |table| EXACT_QUALITIES.fetch(table.values, []) }.reduce(&:&).min
        return result(:exact, exact_quality, 0.0, tables) if exact_quality

        quality, score =
          (1..100).map { |candidate| [candidate, score(tables, candidate)] }.min_by(&:last)
        if score <= MAX_APPROXIMATE_LOG_RMSE
          result(:approximate, quality, Math.exp(score) - 1, tables)
        else
          unknown("DQT tables are not close to a single IJG/libjpeg quality", tables)
        end
      end

      private

      def active_tables
        ids = @parsed_jpeg.used_table_ids
        ids = @parsed_jpeg.tables.keys if ids.empty?
        ids.uniq.filter_map { |id| @parsed_jpeg.tables[id] }
      end

      def result(status, quality, deviation, tables)
        Estimate.new(
          status: status,
          quality: quality,
          deviation: deviation,
          table_count: tables.length,
          precisions: tables.map(&:precision).uniq.sort,
        )
      end

      def score(tables, quality)
        candidates = CANDIDATE_TABLES.fetch(quality)
        total =
          tables.sum do |table|
            candidates
              .map do |candidate|
                table
                  .values
                  .zip(candidate)
                  .sum { |actual, expected| Math.log(actual.to_f / expected)**2 } / 64.0
              end
              .min
          end

        Math.sqrt(total / tables.length)
      end

      def unknown(reason, tables = [])
        Estimate.new(
          status: :unknown,
          table_count: tables.length,
          precisions: tables.map(&:precision).uniq.sort,
          reason: reason,
        )
      end
    end

    def self.estimate(source)
      io = source.respond_to?(:read) ? source : File.open(source, "rb")
      Estimator.new(Parser.new(io).parse).estimate
    ensure
      io&.close unless source.respond_to?(:read)
    end
  end
end
