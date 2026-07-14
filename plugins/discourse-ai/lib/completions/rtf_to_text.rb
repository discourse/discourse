# frozen_string_literal: true

module DiscourseAi
  module Completions
    class RtfToText
      MAX_INPUT_BYTES = 2 * 1024 * 1024
      MAX_EXTRACTED_TEXT_CHARS = 100_001
      MAX_GROUP_DEPTH = 100
      MAX_CONTROL_WORD_CHARS = 64

      GroupState = Struct.new(:skip, :uc, keyword_init: true)

      DESTINATION_CONTROL_WORDS = %w[
        annotation
        atnauthor
        atntime
        author
        buptim
        category
        colorschememapping
        colortbl
        comment
        company
        creatim
        datafield
        datastore
        doccomm
        docvar
        factoidname
        falt
        filetbl
        fldinst
        fonttbl
        footer
        footerf
        footerl
        footerr
        footnote
        formfield
        generator
        header
        headerf
        headerl
        headerr
        info
        keywords
        latentstyles
        listoverridetable
        listtable
        manager
        nextfile
        nonshppict
        object
        objdata
        operator
        pict
        pn
        pnseclvl
        private
        protusertbl
        revtbl
        rsidtbl
        shp
        shpgrp
        shpinst
        stylesheet
        subject
        template
        title
        txe
        userprops
        xmlnstbl
      ].freeze

      CONTROL_TEXT = {
        "bullet" => "•",
        "cell" => "\t",
        "column" => "\t",
        "emdash" => "—",
        "emspace" => " ",
        "endash" => "–",
        "enspace" => " ",
        "ldblquote" => "“",
        "line" => "\n",
        "lquote" => "‘",
        "page" => "\n",
        "par" => "\n",
        "qmspace" => " ",
        "rdblquote" => "”",
        "row" => "\n",
        "rquote" => "’",
        "sect" => "\n",
        "tab" => "\t",
      }.freeze

      ENCODING_BY_CODEPAGE = {
        437 => "IBM437",
        850 => "IBM850",
        852 => "IBM852",
        855 => "IBM855",
        857 => "IBM857",
        860 => "IBM860",
        861 => "IBM861",
        862 => "IBM862",
        863 => "IBM863",
        864 => "IBM864",
        865 => "IBM865",
        866 => "IBM866",
        869 => "IBM869",
        874 => "Windows-874",
        932 => "Windows-31J",
        936 => "GBK",
        949 => "Windows-949",
        950 => "Big5",
        1250 => "Windows-1250",
        1251 => "Windows-1251",
        1252 => "Windows-1252",
        1253 => "Windows-1253",
        1254 => "Windows-1254",
        1255 => "Windows-1255",
        1256 => "Windows-1256",
        1257 => "Windows-1257",
        1258 => "Windows-1258",
        65_001 => "UTF-8",
        20_127 => "US-ASCII",
        20_850 => "IBM850",
        28_591 => "ISO-8859-1",
      }.freeze

      class ParseLimitError < StandardError
      end

      def self.convert(path)
        new(path).convert
      end

      def initialize(path)
        @path = path
      end

      def convert
        @input = read_input
        @index = 0
        @output = +""
        @group_stack = [GroupState.new(skip: false, uc: 1)]
        @source_encoding = find_encoding("Windows-1252")
        @fallback_chars_to_skip = 0

        parse
        normalize_document_text(@output)
      end

      private

      attr_reader :path

      def read_input
        input = File.binread(path, MAX_INPUT_BYTES + 1).to_s
        input = input.byteslice(0, MAX_INPUT_BYTES) if input.bytesize > MAX_INPUT_BYTES
        input.force_encoding(Encoding::BINARY)
      end

      def parse
        while @index < @input.bytesize && @output.length <= MAX_EXTRACTED_TEXT_CHARS
          if @fallback_chars_to_skip.positive?
            skip_fallback_char
            @fallback_chars_to_skip -= 1
            next
          end

          byte = current_byte

          case byte
          when 123 # {
            push_group
          when 125 # }
            pop_group
          when 92 # \
            parse_control
          when 10, 13
            @index += 1
          else
            append_encoded_byte(byte) if !current_group.skip
            @index += 1
          end
        end
      end

      def push_group
        if @group_stack.length >= MAX_GROUP_DEPTH
          raise ParseLimitError, "RTF group nesting is too deep"
        end

        @group_stack << GroupState.new(skip: current_group.skip, uc: current_group.uc)
        @index += 1
      end

      def pop_group
        @group_stack.pop if @group_stack.length > 1
        @index += 1
      end

      def current_group
        @group_stack.last
      end

      def current_byte
        @input.getbyte(@index)
      end

      def parse_control
        @index += 1
        return if @index >= @input.bytesize

        byte = current_byte

        if letter?(byte)
          parse_control_word
        elsif byte == 39 # '
          parse_hex_escape
        else
          parse_control_symbol(byte)
        end
      end

      def parse_control_word
        word = read_control_word
        param = read_control_parameter
        skip_control_space

        handle_control_word(word, param)
      end

      def read_control_word
        stored_length = 0
        word = +""

        while @index < @input.bytesize && letter?(current_byte)
          word << current_byte.chr if stored_length < MAX_CONTROL_WORD_CHARS
          stored_length += 1
          @index += 1
        end

        word.downcase
      end

      def read_control_parameter
        sign = 1
        if current_byte == 45 # -
          sign = -1
          @index += 1
        end

        start = @index
        @index += 1 while @index < @input.bytesize && digit?(current_byte)
        return if start == @index

        @input.byteslice(start, @index - start).to_i * sign
      end

      def skip_control_space
        @index += 1 if current_byte == 32
      end

      def handle_control_word(word, param)
        if DESTINATION_CONTROL_WORDS.include?(word)
          current_group.skip = true
          return
        end

        case word
        when "ansi"
          @source_encoding = find_encoding("Windows-1252")
        when "mac"
          @source_encoding = find_encoding("MacRoman")
        when "pc"
          @source_encoding = find_encoding("IBM437")
        when "pca"
          @source_encoding = find_encoding("IBM850")
        when "ansicpg"
          @source_encoding = encoding_for_codepage(param) if param
        when "uc"
          current_group.uc = param.clamp(0, 10) if param
        when "bin"
          @index += [param.to_i, @input.bytesize - @index].min if param.to_i.positive?
        end

        return if current_group.skip

        if word == "u"
          append_unicode(param)
          @fallback_chars_to_skip = current_group.uc.to_i
        elsif (text = CONTROL_TEXT[word])
          append_text(text)
        end
      end

      def parse_hex_escape
        @index += 1
        hex = @input.byteslice(@index, 2)
        if hex&.match?(/\A[0-9a-fA-F]{2}\z/)
          append_encoded_byte(hex.to_i(16)) if !current_group.skip
          @index += 2
        end
      end

      def parse_control_symbol(byte)
        @index += 1

        case byte
        when 42 # *
          current_group.skip = true
        when 45,
             95 # -, _
          append_text("-") if !current_group.skip
        when 92,
             123,
             125 # \, {, }
          append_text(byte.chr) if !current_group.skip
        when 126 # ~
          append_text(" ") if !current_group.skip
        end
      end

      def skip_fallback_char
        return if @index >= @input.bytesize

        if current_byte == 92 # \
          @index += 1
          return if @index >= @input.bytesize

          if current_byte == 39 # '
            @index += 1
            @index += 2 if @input.byteslice(@index, 2)&.match?(/\A[0-9a-fA-F]{2}\z/)
          elsif letter?(current_byte)
            read_control_word
            read_control_parameter
            skip_control_space
          else
            @index += 1
          end
        else
          @index += 1
        end
      end

      def append_unicode(param)
        return if param.nil?

        codepoint = param.negative? ? param + 65_536 : param
        append_text([codepoint].pack("U")) if codepoint.between?(0, 0x10FFFF)
      rescue RangeError
        nil
      end

      def append_encoded_byte(byte)
        return if byte.nil? || byte == 0

        if byte < 128
          append_text(byte.chr)
        else
          text = byte.chr.b.force_encoding(@source_encoding || Encoding::Windows_1252)
          append_text(text.encode("UTF-8", invalid: :replace, undef: :replace, replace: ""))
        end
      end

      def append_text(text)
        return if text.nil? || text.empty? || @output.length > MAX_EXTRACTED_TEXT_CHARS

        @output << text
      end

      def encoding_for_codepage(codepage)
        find_encoding(ENCODING_BY_CODEPAGE[codepage.to_i]) || @source_encoding
      end

      def find_encoding(name)
        Encoding.find(name)
      rescue ArgumentError
        nil
      end

      def letter?(byte)
        (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122)
      end

      def digit?(byte)
        byte >= 48 && byte <= 57
      end

      def normalize_document_text(text)
        text
          .to_s
          .encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
          .gsub("\u00A0", " ")
          .gsub(/\r\n?/, "\n")
          .gsub(/[ \t]+\n/, "\n")
          .gsub(/\n[ \t]+/, "\n")
          .gsub(/\n{3,}/, "\n\n")
          .strip
      end
    end
  end
end
