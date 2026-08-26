# frozen_string_literal: true

require "discourse_emojis"
require "json"

module Migrations
  module Converters
    module MarkdownEngine
      # The unicode-emoji-to-name replacement table the engine's `__setUnicode`
      # expects. This mirrors `Emoji.unicode_replacements` in the host
      # application, which cannot be required here because the `Emoji` model
      # drags in site caches and settings; both read the same static
      # discourse-emojis data, and a parity spec asserts the outputs stay
      # identical.
      module EmojiData
        FITZPATRICK_SCALE = %w[1f3fb 1f3fc 1f3fd 1f3fe 1f3ff].freeze

        # Kept as text symbols rather than emoji images by the host application.
        SYMBOL_NAMES = %w[registered copyright trade_mark left_right_arrow].freeze

        EXTRA_REPLACEMENTS = {
          "\u{2639}" => "frowning",
          "\u{263B}" => "slight_smile",
          "\u{2661}" => "heart",
          "\u{2665}" => "heart",
        }.freeze

        def self.unicode_replacements
          @unicode_replacements ||=
            begin
              replacements = {}
              tonable = tonable_emojis
              scales = FITZPATRICK_SCALE.map { |scale| scale.to_i(16) }

              emojis_db.each do |emoji|
                name = emoji["name"]
                next if SYMBOL_NAMES.include?(name)

                code = replacement_code(emoji["code"])
                next unless code

                replacements[code] = name
                if tonable.include?(name)
                  scales.each_with_index do |scale, index|
                    codepoints = code.codepoints
                    codepoints.delete_at(1) if codepoints[1] == 0xfe0f
                    toned_code = codepoints.insert(1, scale).pack("U*")
                    replacements[toned_code] = "#{name}:t#{index + 2}"
                  end
                end
              end

              replacements.merge(EXTRA_REPLACEMENTS)
            end
        end

        def self.set_unicode_source
          "__setUnicode(#{unicode_replacements.to_json});"
        end

        def self.data_files
          [DiscourseEmojis.paths[:emojis], DiscourseEmojis.paths[:tonable_emojis]]
        end

        def self.emojis_db
          parse_file(DiscourseEmojis.paths[:emojis])
        end
        private_class_method :emojis_db

        def self.tonable_emojis
          parse_file(DiscourseEmojis.paths[:tonable_emojis])
        end
        private_class_method :tonable_emojis

        def self.parse_file(path)
          File.open(path, "r:UTF-8") { |file| JSON.parse(file.read) }
        end
        private_class_method :parse_file

        def self.replacement_code(code)
          code.split("-").map!(&:hex).pack("U*")
        end
        private_class_method :replacement_code
      end
    end
  end
end
