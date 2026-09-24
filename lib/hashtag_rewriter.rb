# frozen_string_literal: true

class HashtagRewriter
  def self.sql_like_pattern(ref)
    "%##{ActiveRecord::Base.sanitize_sql_like(ref)}%"
  end

  def self.usable_ref?(ref)
    return false if ref.blank?

    PrettyText.scan_hashtags(" ##{ref} ") == [ref]
  end

  def initialize(raw, cook_options = {})
    @raw = raw.to_s
    @cook_options = cook_options
  end

  def rewrite
    wanted = {}

    refs.each_with_index do |ref, index|
      replacement = yield(ref)
      wanted[index] = replacement if replacement.present?
    end
    return @raw if wanted.empty?

    live = probed_as_hashtag(wanted)
    return @raw if live.empty?

    faithful = faithful_subset(live)
    return @raw if faithful.empty?

    splice(faithful)
  end

  private

  def refs
    @refs ||= PrettyText.scan_hashtags(@raw)
  end

  def splice(replacements)
    PrettyText.splice_hashtags(@raw, replacements)
  end

  def cooked(raw)
    PrettyText.markdown(raw, @cook_options.dup)
  end

  def probed_as_hashtag(wanted)
    markers = wanted.keys.index_with { |index| marker(index) }
    probed = Nokogiri::HTML5.fragment(cooked(splice(markers)))
    spans = probed.css("span.hashtag-raw").map(&:text).to_set

    wanted.select { |index, _| spans.include?("##{markers[index]}") }
  end

  def faithful_subset(live)
    return live if faithful?(live)

    kept = {}

    live.each do |index, replacement|
      kept[index] = replacement if faithful?(kept.merge(index => replacement))
    end

    kept
  end

  def faithful?(replacements)
    @baseline ||= hashtag_blind(cooked(@raw))

    hashtag_blind(cooked(splice(replacements))) == @baseline
  end

  def hashtag_blind(html)
    doc = Nokogiri::HTML5.fragment(html)

    doc.css("span.hashtag-raw, a.hashtag-cooked").each { |node| node.replace(nonce) }

    doc
      .css("a.anchor")
      .each do |node|
        node["name"] = ""
        node["href"] = ""
      end

    doc.to_html
  end

  def marker(index)
    "#{nonce}#{index}z"
  end

  def nonce
    @nonce ||=
      loop do
        candidate = "z#{SecureRandom.hex(6)}z"
        break candidate if @raw.exclude?(candidate)
      end
  end
end
