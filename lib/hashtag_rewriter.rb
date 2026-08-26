# frozen_string_literal: true

class HashtagRewriter
  LEADING_BOUNDARY = "(?<![^[:space:][:punct:]])(?<!/)"
  TRAILING_BOUNDARY = "(?![^[:space:][:punct:]])"
  REF = "[À-῿Ⰰ-퟿\\w:-](?:[À-῿Ⰰ-퟿\\w:.-]{0,99}[À-῿Ⰰ-퟿\\w:-])?"
  HASHTAG = Regexp.new("#{LEADING_BOUNDARY}#(#{REF})#{TRAILING_BOUNDARY}")

  def self.sql_pattern(ref)
    "#{LEADING_BOUNDARY}##{Regexp.escape(ref)}#{TRAILING_BOUNDARY}"
  end

  def self.usable_ref?(ref)
    return false if ref.blank?

    match = HASHTAG.match(" ##{ref} ")
    match.present? && match[1] == ref
  end

  def initialize(raw, cook_options = {})
    @raw = raw.to_s
    @cook_options = cook_options
  end

  def rewrite(&block)
    wanted = {}

    probed =
      each_hashtag do |index, ref|
        replacement = block.call(ref)
        next "##{unresolvable_prefix}" if replacement.blank?

        wanted[index] = replacement
        "##{unresolvable_ref(index)}"
      end

    return @raw if wanted.empty?

    live = cooked_as_hashtag(probed, wanted)
    return @raw if live.empty?

    each_hashtag { |index, _| "##{live[index]}" if live.key?(index) }
  end

  private

  def each_hashtag
    index = -1

    @raw.gsub(HASHTAG) { |match| yield(index += 1, Regexp.last_match(1)) || match }
  end

  def cooked_as_hashtag(probed, wanted)
    cooked = PrettyText.markdown(probed, @cook_options.dup)

    wanted.select do |index, _|
      cooked.include?(%{<span class="hashtag-raw">##{unresolvable_ref(index)}</span>})
    end
  end

  def unresolvable_ref(index)
    "#{unresolvable_prefix}#{index}z"
  end

  def unresolvable_prefix
    @unresolvable_prefix ||=
      loop do
        prefix = "z#{SecureRandom.hex(6)}z"
        break prefix if @raw.exclude?(prefix)
      end
  end
end
