# frozen_string_literal: true

# Normalizes the upload markdown produced when `[upload|id]` placeholders are replaced during a
# bulk import, so it cooks correctly regardless of the surrounding context the source content
# placed it in. Three independent defects, each of which otherwise leaves the upload as literal
# text (no <img>/<a>, and therefore no upload_reference):
#
#   1. GFM table cell  — `![label|WxH](upload://…)` carries a literal `|` that a table row reads
#      as a column separator, shredding the image. Escaped as `\|` (renders identically; verified
#      with PrettyText.cook across inline/standalone/table/attachment/scaled).
#   2. Block HTML      — an upload placed directly inside a block tag (e.g. <td>…</td>) is passed
#      through verbatim by markdown-it. Surrounded with blank lines so it is cooked as markdown.
#   3. Indented code   — an upload line indented 4+ spaces (or a tab) becomes an indented code
#      block. De-indented, but only for standalone lines (list-continuation lines are preserved).
#
# Every transform is a no-op unless its exact pattern is present, and every transform is
# idempotent (safe to apply repeatedly).
module UploadMarkdownNormalizer
  UPLOAD = %r{!?\[[^\]]*\]\(upload://[^)]+\)}

  # The label class excludes `\` (as well as `]`/`|`) so an already-escaped `\|` is not matched
  # again — keeps the escape idempotent (no `\\|` on a second pass).
  UPLOAD_PIPE_PATTERNS = [
    %r{(!\[[^\]|\\]*)\|(\d{1,4}x\d{1,4}(?:,\s*\d{1,3}%)?\]\(upload://[^)]+\))}, # image + dimensions
    %r{(\[[^\]|\\]*)\|(attachment\]\(upload://[^)]+\))}, # attachment
    %r{(!\[[^\]|\\]*)\|((?:audio|video)\]\(upload://[^)]+\))}, # audio/video
  ].freeze

  HTML_BLOCK_TAGS =
    "table|thead|tbody|tfoot|tr|td|th|div|p|li|ul|ol|dl|dd|dt|blockquote|details|summary|" \
      "section|article|center|figure|figcaption"

  LIST_ITEM_RE = /\A\s*(?:[-*+]|\d+[.)])\s/
  INDENTED_UPLOAD_RE = %r{\A([ \t]+)(!?\[[^\]]*\]\(upload://.*)\z}

  module_function

  # Apply every fix. Cheap to call on any raw; returns it unchanged when no upload markdown.
  def normalize(raw)
    surround_html_uploads(escape_table_pipes(dedent_upload_lines(raw)))
  end

  # Escape upload-markdown pipes on GFM full-pipe table rows.
  def escape_table_pipes(raw)
    raw
      .split("\n", -1)
      .map do |line|
        next line unless line.match?(/\A\s*\|.*\|\s*\z/)
        UPLOAD_PIPE_PATTERNS.each { |re| line = line.gsub(re) { "#{$1}\\|#{$2}" } }
        line
      end
      .join("\n")
  end

  # Surround upload markdown with blank lines when it sits directly inside a block HTML tag.
  def surround_html_uploads(raw)
    raw = raw.gsub(/(<(?:#{HTML_BLOCK_TAGS})\b[^>]*>)[ \t]*(#{UPLOAD})/o) { "#{$1}\n\n#{$2}" }
    raw.gsub(%r{(#{UPLOAD})[ \t]*(</?(?:#{HTML_BLOCK_TAGS})\b[^>]*>)}o) { "#{$1}\n\n#{$2}" }
  end

  # Strip leading indentation from a standalone upload line that would otherwise be parsed as an
  # indented code block. List-continuation lines are left untouched (their indentation is what
  # keeps the upload inside the list item).
  def dedent_upload_lines(raw)
    lines = raw.split("\n", -1)
    prev_nonblank = nil

    lines.each_index do |i|
      if (m = lines[i].match(INDENTED_UPLOAD_RE))
        indented_code = m[1].include?("\t") || m[1].length >= 4
        in_list =
          prev_nonblank &&
            (prev_nonblank.match?(LIST_ITEM_RE) || prev_nonblank.match?(/\A[ \t]{4,}\S/))
        lines[i] = m[2] if indented_code && !in_list
      end

      prev_nonblank = lines[i] unless lines[i].strip.empty?
    end

    lines.join("\n")
  end
end
