# frozen_string_literal: true

class BbcodeRewriter
  # SyntaxTree compacts the exception declarations below.
  # rubocop:disable Layout/EmptyLineBetweenDefs
  class Error < StandardError
  end
  class TargetNotFound < Error
  end
  class AmbiguousTarget < Error
  end
  class UnsupportedRenderer < Error
  end
  class InvalidRewrite < Error
  end

  # rubocop:enable Layout/EmptyLineBetweenDefs

  def initialize(raw, tag:, selector:, cook_options: {})
    @raw = raw.to_s.dup.freeze
    @tag = tag.to_s.downcase
    @selector = selector
    @cook_options = cook_options.deep_dup

    raise ArgumentError, "Invalid BBCode tag" unless @tag.match?(/\A[a-z][a-z0-9_-]*\z/)
  end

  def rewrite(changes)
    raise ArgumentError, "Changes must be a Hash" unless changes.is_a?(Hash)

    candidate = target
    return @raw if changes.empty?

    PrettyText.rewrite_bbcode_tag(
      @raw,
      tag: @tag,
      candidate: candidate.fetch("index"),
      expected_opening: candidate.fetch("opening"),
      changes: changes.stringify_keys,
    )
  rescue MiniRacer::RuntimeError => error
    raise InvalidRewrite, error.message
  end

  private

  def cook(raw)
    PrettyText.markdown(raw, @cook_options.deep_dup)
  end

  def target
    return @target if defined?(@target)

    candidates = PrettyText.scan_bbcode_tags(@raw, tag: @tag)
    raise TargetNotFound, "No #{@tag} opening tag found" if candidates.empty?

    prefix = marker_prefix
    attribute = "bbcoderewriter#{prefix}"
    data_attribute = "data-#{attribute}"
    marked_raw = PrettyText.mark_bbcode_tags(@raw, tag: @tag, attribute:, prefix:)
    document = Nokogiri::HTML5.fragment(cook(marked_raw))
    tokens = candidates.index_by { |candidate| "#{prefix}-#{candidate.fetch("index")}" }
    selected_nodes = document.css(@selector)
    marked_nodes = selected_nodes.select { |node| tokens.key?(node[data_attribute]) }

    if marked_nodes.empty?
      if Nokogiri::HTML5.fragment(cook(@raw)).css(@selector).any?
        raise UnsupportedRenderer, "Renderer did not expose the BBCode marker"
      end

      raise TargetNotFound, "No rendered #{@tag} target found"
    end

    if selected_nodes.size != marked_nodes.size
      raise UnsupportedRenderer, "Some rendered targets did not expose a BBCode marker"
    end

    raise AmbiguousTarget, "More than one rendered #{@tag} target found" if marked_nodes.size > 1

    candidate = tokens.fetch(marked_nodes.first[data_attribute])
    marked_raw =
      PrettyText.mark_bbcode_tags(
        @raw,
        tag: @tag,
        attribute:,
        prefix:,
        candidate: candidate.fetch("index"),
      )
    document = Nokogiri::HTML5.fragment(cook(marked_raw))
    nodes = document.css(@selector)
    token = "#{prefix}-#{candidate.fetch("index")}"

    unless nodes.size == 1 && nodes.first[data_attribute] == token
      raise UnsupportedRenderer, "The selected marker did not identify a unique rendered target"
    end

    document.css("[#{data_attribute}]").each { |node| node.remove_attribute(data_attribute) }
    baseline = Nokogiri::HTML5.fragment(cook(@raw)).to_html

    unless document.to_html == baseline
      raise UnsupportedRenderer, "Adding the BBCode marker changed the rendered content"
    end

    @target = candidate
  end

  def marker_prefix
    loop do
      prefix = SecureRandom.hex(12)
      return prefix if @raw.exclude?(prefix)
    end
  end
end
