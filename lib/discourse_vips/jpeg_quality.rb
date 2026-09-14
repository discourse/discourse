# frozen_string_literal: true

module DiscourseVips
  # Estimates JPEG quality for optional recompression using ImageMagick's table heuristic.
  # Copyright 1999 ImageMagick Studio LLC. Based in part on the Independent JPEG Group's work.
  # Translated and modified for Discourse with bounded JPEG header parsing from ImageMagick 7.1.2-27:
  # https://github.com/ImageMagick/ImageMagick/blob/b661ac969aa3a0d326690f95830aab246569f090/coders/jpeg.c#L1197-L1325
  # https://github.com/ImageMagick/ImageMagick/blob/b661ac969aa3a0d326690f95830aab246569f090/MagickCore/property.c#L2742-L2747
  # License: https://github.com/ImageMagick/ImageMagick/blob/b661ac969aa3a0d326690f95830aab246569f090/LICENSE
  # Lossless input stays unknown because the production decoder rejects it before the helper's 100 branch.
  module JpegQuality
    class Error < StandardError
    end

    class InvalidJPEG < Error
    end

    Estimate =
      Struct.new(:status, :quality, :table_count, :precisions, :reason, keyword_init: true) do
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
    ParsedJPEG = Struct.new(:tables, :used_table_ids, :components, :lossless, keyword_init: true)

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

      ZIGZAG = [
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
      private_constant :ZIGZAG

      def initialize(io)
        @io = io
        @tables = {}
        @used_table_ids = []
        @lossless = false
        @header_bytes = 0
        @frame_seen = false
        @components = []
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

        ParsedJPEG.new(
          tables: @tables,
          used_table_ids: @used_table_ids,
          components: @components,
          lossless: @lossless,
        )
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
            values:
              values
                .each_with_index
                .with_object(Array.new(64)) do |(value, index), natural|
                  natural[ZIGZAG[index]] = value
                end
                .freeze,
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
          @components << [payload.getbyte(6 + (index * 3)), table_id]

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
      COLOR_COEFFICIENT_SUMS = [
        1020,
        1015,
        932,
        848,
        780,
        735,
        702,
        679,
        660,
        645,
        632,
        623,
        613,
        607,
        600,
        594,
        589,
        585,
        581,
        571,
        555,
        542,
        529,
        514,
        494,
        474,
        457,
        439,
        424,
        410,
        397,
        386,
        373,
        364,
        351,
        341,
        334,
        324,
        317,
        309,
        299,
        294,
        287,
        279,
        274,
        267,
        262,
        257,
        251,
        247,
        243,
        237,
        232,
        227,
        222,
        217,
        213,
        207,
        202,
        198,
        192,
        188,
        183,
        177,
        173,
        168,
        163,
        157,
        153,
        148,
        143,
        139,
        132,
        128,
        125,
        119,
        115,
        108,
        104,
        99,
        94,
        90,
        84,
        79,
        74,
        70,
        64,
        59,
        55,
        49,
        45,
        40,
        34,
        30,
        25,
        20,
        15,
        11,
        6,
        4,
        0,
      ].freeze
      private_constant :COLOR_COEFFICIENT_SUMS

      COLOR_TABLE_SUMS = [
        32_640,
        32_635,
        32_266,
        31_495,
        30_665,
        29_804,
        29_146,
        28_599,
        28_104,
        27_670,
        27_225,
        26_725,
        26_210,
        25_716,
        25_240,
        24_789,
        24_373,
        23_946,
        23_572,
        22_846,
        21_801,
        20_842,
        19_949,
        19_121,
        18_386,
        17_651,
        16_998,
        16_349,
        15_800,
        15_247,
        14_783,
        14_321,
        13_859,
        13_535,
        13_081,
        12_702,
        12_423,
        12_056,
        11_779,
        11_513,
        11_135,
        10_955,
        10_676,
        10_392,
        10_208,
        9928,
        9747,
        9564,
        9369,
        9193,
        9017,
        8822,
        8639,
        8458,
        8270,
        8084,
        7896,
        7710,
        7527,
        7347,
        7156,
        6977,
        6788,
        6607,
        6422,
        6236,
        6054,
        5867,
        5684,
        5495,
        5305,
        5128,
        4945,
        4751,
        4638,
        4442,
        4248,
        4065,
        3888,
        3698,
        3509,
        3326,
        3139,
        2957,
        2775,
        2586,
        2405,
        2216,
        2037,
        1846,
        1666,
        1483,
        1297,
        1109,
        927,
        735,
        554,
        375,
        201,
        128,
        0,
      ].freeze
      private_constant :COLOR_TABLE_SUMS

      GRAYSCALE_COEFFICIENT_SUMS = [
        510,
        505,
        422,
        380,
        355,
        338,
        326,
        318,
        311,
        305,
        300,
        297,
        293,
        291,
        288,
        286,
        284,
        283,
        281,
        280,
        279,
        278,
        277,
        273,
        262,
        251,
        243,
        233,
        225,
        218,
        211,
        205,
        198,
        193,
        186,
        181,
        177,
        172,
        168,
        164,
        158,
        156,
        152,
        148,
        145,
        142,
        139,
        136,
        133,
        131,
        129,
        126,
        123,
        120,
        118,
        115,
        113,
        110,
        107,
        105,
        102,
        100,
        97,
        94,
        92,
        89,
        87,
        83,
        81,
        79,
        76,
        74,
        70,
        68,
        66,
        63,
        61,
        57,
        55,
        52,
        50,
        48,
        44,
        42,
        39,
        37,
        34,
        31,
        29,
        26,
        24,
        21,
        18,
        16,
        13,
        11,
        8,
        6,
        3,
        2,
        0,
      ].freeze
      private_constant :GRAYSCALE_COEFFICIENT_SUMS

      GRAYSCALE_TABLE_SUMS = [
        16_320,
        16_315,
        15_946,
        15_277,
        14_655,
        14_073,
        13_623,
        13_230,
        12_859,
        12_560,
        12_240,
        11_861,
        11_456,
        11_081,
        10_714,
        10_360,
        10_027,
        9679,
        9368,
        9056,
        8680,
        8331,
        7995,
        7668,
        7376,
        7084,
        6823,
        6562,
        6345,
        6125,
        5939,
        5756,
        5571,
        5421,
        5240,
        5086,
        4976,
        4829,
        4719,
        4616,
        4463,
        4393,
        4280,
        4166,
        4092,
        3980,
        3909,
        3835,
        3755,
        3688,
        3621,
        3541,
        3467,
        3396,
        3323,
        3247,
        3170,
        3096,
        3021,
        2952,
        2874,
        2804,
        2727,
        2657,
        2583,
        2509,
        2437,
        2362,
        2290,
        2211,
        2136,
        2068,
        1996,
        1915,
        1858,
        1773,
        1692,
        1620,
        1552,
        1477,
        1398,
        1326,
        1251,
        1179,
        1109,
        1031,
        961,
        884,
        814,
        736,
        667,
        592,
        518,
        441,
        369,
        292,
        221,
        151,
        86,
        64,
        0,
      ].freeze
      private_constant :GRAYSCALE_TABLE_SUMS

      def initialize(parsed_jpeg)
        @parsed_jpeg = parsed_jpeg
      end

      def estimate
        tables = @parsed_jpeg.tables
        return result(:unknown, nil) if @parsed_jpeg.lossless
        return result(:undefined, 92) unless tables[0]

        total = tables.values.sum { |table| table.values.sum }
        coefficients = tables[0].values[2] + tables[0].values[53]
        if tables[1]
          coefficients += tables[1].values[0] + tables[1].values[63]
          coefficient_sums = COLOR_COEFFICIENT_SUMS
          table_sums = COLOR_TABLE_SUMS
        else
          coefficient_sums = GRAYSCALE_COEFFICIENT_SUMS
          table_sums = GRAYSCALE_TABLE_SUMS
        end

        100.times do |index|
          next if coefficients < coefficient_sums[index] && total < table_sums[index]

          exact = coefficients <= coefficient_sums[index] && total <= table_sums[index]
          return result(exact ? :exact : :approximate, index + 1) if exact || index >= 50

          return result(:undefined, 92)
        end
        result(:undefined, 92)
      end

      private

      def result(status, quality)
        tables = @parsed_jpeg.tables.values
        Estimate.new(
          status: status,
          quality: quality,
          table_count: tables.length,
          precisions: tables.map(&:precision).uniq.sort,
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
