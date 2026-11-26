# frozen_string_literal: true

# heavily based off
# https://github.com/vmg/redcarpet/blob/master/ext/redcarpet/html_smartypants.c
# and
# https://github.com/jmcnevin/rubypants/blob/master/lib/rubypants/core.rb
# 99% of the code here is by Jeremy McNevin
#
# This Source File is available under BSD/MIT license as well as standard GPL
#

class HtmlPrettify < String
  DEFAULT_ENTITIES = {
    single_left_quote: "&lsquo;",
    double_left_quote: "&ldquo;",
    single_right_quote: "&rsquo;",
    double_right_quote: "&rdquo;",
    em_dash: "&mdash;",
    en_dash: "&ndash;",
    ellipsis: "&hellip;",
    html_quote: "&quot;",
    frac12: "&frac12;",
    frac14: "&frac14;",
    frac34: "&frac34;",
  }.freeze

  DEFAULT_SPECIAL_CHARS_RE = %r{['"`\-./&]}
  TAG_SOUP_RE = /([^<]*)(<[^>]*>)/
  PRE_TAG_RE = %r{<(/?)(?:pre|code|kbd|script|math)[\s>]}
  FRAC_RE = %r{(\s+|^)(1/4|1/2|3/4)([,.;\s]|$)}
  TRAILING_SPACE_RE = /\s\z/

  PUNCT_CLASS = '[!"#\$\%\'()*+,\-.\/:;<=>?\@\[\\\\\]\^_`{|}~]'
  CLOSE_CLASS = %![^\ \t\r\n\\[\{\(\-]!
  DEFAULT_DEC_DASHES = "&ndash;|&mdash;"

  SQ_PUNCT_START_RE = /\A'(?=#{PUNCT_CLASS}\B)/
  DQ_PUNCT_START_RE = /\A"(?=#{PUNCT_CLASS}\B)/
  DQ_SQ_OPEN_RE = /"'(?=\w)/
  SQ_DQ_OPEN_RE = /'"(?=\w)/
  DECADE_RE = /'(?=\d\ds)/
  DEFAULT_SQ_OPEN_RE = /(\s|&nbsp;|=|--|&[mn]dash;|#{DEFAULT_DEC_DASHES}|&#x201[34];)'(?=\w)/
  SQ_CLOSE_1_RE = /(#{CLOSE_CLASS})'/
  SQ_CLOSE_2_RE = /'(\s|s\b|$)/
  DEFAULT_DQ_OPEN_RE = /(\s|&nbsp;|=|--|&[mn]dash;|#{DEFAULT_DEC_DASHES}|&#x201[34];)"(?=\w)/
  DQ_CLOSE_1_RE = /(#{CLOSE_CLASS})"/
  DQ_CLOSE_2_RE = /"(\s|s\b|$)/

  private_constant :DEFAULT_ENTITIES,
                   :DEFAULT_SPECIAL_CHARS_RE,
                   :TAG_SOUP_RE,
                   :PRE_TAG_RE,
                   :FRAC_RE,
                   :TRAILING_SPACE_RE,
                   :PUNCT_CLASS,
                   :CLOSE_CLASS,
                   :DEFAULT_DEC_DASHES,
                   :SQ_PUNCT_START_RE,
                   :DQ_PUNCT_START_RE,
                   :DQ_SQ_OPEN_RE,
                   :SQ_DQ_OPEN_RE,
                   :DECADE_RE,
                   :DEFAULT_SQ_OPEN_RE,
                   :SQ_CLOSE_1_RE,
                   :SQ_CLOSE_2_RE,
                   :DEFAULT_DQ_OPEN_RE,
                   :DQ_CLOSE_1_RE,
                   :DQ_CLOSE_2_RE

  def self.render(html)
    render_default(html)
  end

  def self.render_default(html)
    if !html.include?("<")
      out, = transform_default_text(html, nil)
      return out.equal?(html) ? String.new(html) : out
    end

    in_pre = false
    result = +""
    prev_non_space = nil
    prev_end = 0

    html.scan(TAG_SOUP_RE) do
      text_part = $1
      tag_part = $2
      prev_end = $~.end(0)

      if !text_part.empty?
        if in_pre
          prev_non_space = !TRAILING_SPACE_RE.match?(text_part)
          result << text_part
        else
          transformed, prev_non_space = transform_default_text(text_part, prev_non_space)
          result << transformed
        end
      end

      result << tag_part
      in_pre = ($1 != "/") if tag_part =~ PRE_TAG_RE
    end

    if prev_end < html.size
      tail = html[prev_end..-1]
      if in_pre
        result << tail
      else
        transformed, = transform_default_text(tail, prev_non_space)
        result << transformed
      end
    end

    result
  end
  private_class_method :render_default

  def self.transform_default_text(raw, prev_non_space)
    last_non_space = raw.empty? ? nil : !TRAILING_SPACE_RE.match?(raw)
    return raw, last_non_space if !DEFAULT_SPECIAL_CHARS_RE.match?(raw)

    t = raw.dup
    if t.include?("&")
      t.gsub!("&#39;", "'")
      t.gsub!("&quot;", '"')
    end
    if t.include?("--")
      t.gsub!("---", "&mdash;")
      t.gsub!("--", "&ndash;")
    end
    if t.include?(".")
      t.gsub!("...", "&hellip;")
      t.gsub!(". . .", "&hellip;")
    end
    if t.include?("/")
      t.gsub!(FRAC_RE) do
        frac =
          case $2
          when "1/2"
            "&frac12;"
          when "1/4"
            "&frac14;"
          when "3/4"
            "&frac34;"
          end
        "#{$1}#{frac}#{$3}"
      end
    end
    if t.include?("``") || t.include?("''")
      t.gsub!("``", "&ldquo;")
      t.gsub!("''", "&rdquo;")
    end

    if t == "'"
      t = prev_non_space ? "&rsquo;" : "&lsquo;"
    elsif t == '"'
      t = prev_non_space ? "&rdquo;" : "&ldquo;"
    elsif t.include?("'") || t.include?('"')
      has_sq = t.include?("'")
      has_dq = t.include?('"')
      t.gsub!(SQ_PUNCT_START_RE, "&rsquo;") if has_sq
      t.gsub!(DQ_PUNCT_START_RE, "&rdquo;") if has_dq
      if has_sq && has_dq
        t.gsub!(DQ_SQ_OPEN_RE, "&ldquo;&lsquo;")
        t.gsub!(SQ_DQ_OPEN_RE, "&lsquo;&ldquo;")
      end
      if has_sq
        t.gsub!(DECADE_RE, "&rsquo;")
        t.gsub!(DEFAULT_SQ_OPEN_RE, '\1&lsquo;')
        t.gsub!(SQ_CLOSE_1_RE, '\1&rsquo;')
        t.gsub!(SQ_CLOSE_2_RE, '&rsquo;\1')
        t.gsub!("'", "&lsquo;")
      end
      if has_dq
        t.gsub!(DEFAULT_DQ_OPEN_RE, '\1&ldquo;')
        t.gsub!(DQ_CLOSE_1_RE, '\1&rdquo;')
        t.gsub!(DQ_CLOSE_2_RE, '&rdquo;\1')
        t.gsub!('"', "&ldquo;")
      end
    end

    [t, last_non_space]
  end
  private_class_method :transform_default_text

  # Create a new RubyPants instance with the text in +string+.
  #
  # Allowed elements in the options array:
  #
  # 0  :: do nothing
  # 1  :: enable all, using only em-dash shortcuts
  # 2  :: enable all, using old school en- and em-dash shortcuts (*default*)
  # 3  :: enable all, using inverted old school en and em-dash shortcuts
  # -1 :: stupefy (translate HTML entities to their ASCII-counterparts)
  #
  # If you don't like any of these defaults, you can pass symbols to change
  # RubyPants' behavior:
  #
  # <tt>:quotes</tt>        :: quotes
  # <tt>:backticks</tt>     :: backtick quotes (``double'' only)
  # <tt>:allbackticks</tt>  :: backtick quotes (``double'' and `single')
  # <tt>:dashes</tt>        :: dashes
  # <tt>:oldschool</tt>     :: old school dashes
  # <tt>:inverted</tt>      :: inverted old school dashes
  # <tt>:ellipses</tt>      :: ellipses
  # <tt>:convertquotes</tt> :: convert <tt>&quot;</tt> entities to
  #                            <tt>"</tt>
  # <tt>:stupefy</tt>       :: translate RubyPants HTML entities
  #                            to their ASCII counterparts.
  #
  # In addition, you can customize the HTML entities that will be injected by
  # passing in a hash for the final argument.  The defaults for these entities
  # are as follows:
  #
  # <tt>:single_left_quote</tt>  :: <tt>&#8216;</tt>
  # <tt>:double_left_quote</tt>  :: <tt>&#8220;</tt>
  # <tt>:single_right_quote</tt> :: <tt>&#8217;</tt>
  # <tt>:double_right_quote</tt> :: <tt>&#8221;</tt>
  # <tt>:em_dash</tt>            :: <tt>&#8212;</tt>
  # <tt>:en_dash</tt>            :: <tt>&#8211;</tt>
  # <tt>:ellipsis</tt>           :: <tt>&#8230;</tt>
  # <tt>:html_quote</tt>         :: <tt>&quot; </tt>
  #
  def initialize(string, options = [2], entities = {})
    super string

    @options = [*options]
    @default_entities_used = entities.empty?
    @entities = @default_entities_used ? DEFAULT_ENTITIES : DEFAULT_ENTITIES.merge(entities)
  end

  # Apply SmartyPants transformations.
  def to_html
    return self.class.render(self) if @default_entities_used && @options == [2]

    do_quotes = do_backticks = do_dashes = do_ellipses = nil

    if @options.include?(0)
      # Do nothing.
      return self
    elsif @options.include?(1)
      # Do everything, turn all options on.
      do_quotes = do_backticks = do_ellipses = true
      do_dashes = :normal
    elsif @options.include?(2)
      # Do everything, turn all options on, use old school dash shorthand.
      do_quotes = do_backticks = do_ellipses = true
      do_dashes = :oldschool
    elsif @options.include?(3)
      # Do everything, turn all options on, use inverted old school
      # dash shorthand.
      do_quotes = do_backticks = do_ellipses = true
      do_dashes = :inverted
    elsif @options.include?(-1)
      do_stupefy = true
    else
      do_quotes = @options.include?(:quotes)
      do_backticks = @options.include?(:backticks)
      do_backticks = :both if @options.include?(:allbackticks)
      do_dashes = :normal if @options.include?(:dashes)
      do_dashes = :oldschool if @options.include?(:oldschool)
      do_dashes = :inverted if @options.include?(:inverted)
      do_ellipses = @options.include?(:ellipses)
      do_stupefy = @options.include?(:stupefy)
    end

    # Parse the HTML
    tokens = tokenize

    # Keep track of when we're inside <pre> or <code> tags.
    in_pre = false

    # Here is the result stored in.
    result = +""

    # This is a cheat, used to get some context for one-character
    # tokens that consist of just a quote char. What we do is remember
    # the last character of the previous text token, to use as context
    # to curl single- character quote tokens correctly.
    prev_token_last_char = nil

    tokens.each do |token|
      if token.first == :tag
        result << token[1]
        if token[1] =~ PRE_TAG_RE
          in_pre = ($1 != "/") # Opening or closing tag?
        end
      else
        t = token[1]

        # Remember last char of this token before processing.
        last_char = t[-1].chr

        if !in_pre
          t.gsub!("&#39;", "'")
          t.gsub!("&quot;", '"')

          if do_dashes
            t = educate_dashes t if do_dashes == :normal
            t = educate_dashes_oldschool t if do_dashes == :oldschool
            t = educate_dashes_inverted t if do_dashes == :inverted
          end

          t = educate_ellipses t if do_ellipses

          t = educate_fractions t

          # Note: backticks need to be processed before quotes.
          if do_backticks
            t = educate_backticks t
            t = educate_single_backticks t if do_backticks == :both
          end

          if do_quotes
            if t == "'"
              # Special case: single-character ' token
              t =
                if prev_token_last_char =~ /\S/
                  entity(:single_right_quote)
                else
                  entity(:single_left_quote)
                end
            elsif t == '"'
              # Special case: single-character " token
              t =
                if prev_token_last_char =~ /\S/
                  entity(:double_right_quote)
                else
                  entity(:double_left_quote)
                end
            else
              # Normal case:
              t = educate_quotes t
            end
          end

          t = stupefy_entities t if do_stupefy
        end

        prev_token_last_char = last_char
        result << t
      end
    end

    # Done
    result
  end

  protected

  # The string, with each instance of "<tt>--</tt>" translated to an
  # em-dash HTML entity.
  #
  def educate_dashes(str)
    str.gsub(/--/, entity(:em_dash))
  end

  # The string, with each instance of "<tt>--</tt>" translated to an
  # en-dash HTML entity, and each "<tt>---</tt>" translated to an
  # em-dash HTML entity.
  #
  def educate_dashes_oldschool(str)
    str.gsub(/---/, entity(:em_dash)).gsub(/--/, entity(:en_dash))
  end

  # Return the string, with each instance of "<tt>--</tt>" translated
  # to an em-dash HTML entity, and each "<tt>---</tt>" translated to
  # an en-dash HTML entity. Two reasons why: First, unlike the en- and
  # em-dash syntax supported by +educate_dashes_oldschool+, it's
  # compatible with existing entries written before SmartyPants 1.1,
  # back when "<tt>--</tt>" was only used for em-dashes.  Second,
  # em-dashes are more common than en-dashes, and so it sort of makes
  # sense that the shortcut should be shorter to type. (Thanks to
  # Aaron Swartz for the idea.)
  #
  def educate_dashes_inverted(str)
    str.gsub(/---/, entity(:en_dash)).gsub(/--/, entity(:em_dash))
  end

  # Return the string, with each instance of "<tt>...</tt>" translated
  # to an ellipsis HTML entity. Also converts the case where there are
  # spaces between the dots.
  #
  def educate_ellipses(str)
    str.gsub("...", entity(:ellipsis)).gsub(". . .", entity(:ellipsis))
  end

  # Return the string, with "<tt>``backticks''</tt>"-style single quotes
  # translated into HTML curly quote entities.
  #
  def educate_backticks(str)
    str.gsub("``", entity(:double_left_quote)).gsub("''", entity(:double_right_quote))
  end

  # Return the string, with "<tt>`backticks'</tt>"-style single quotes
  # translated into HTML curly quote entities.
  #
  def educate_single_backticks(str)
    str.gsub("`", entity(:single_left_quote)).gsub("'", entity(:single_right_quote))
  end

  def educate_fractions(str)
    str.gsub(FRAC_RE) do
      frac =
        if $2 == "1/2"
          entity(:frac12)
        elsif $2 == "1/4"
          entity(:frac14)
        elsif $2 == "3/4"
          entity(:frac34)
        end
      "#{$1}#{frac}#{$3}"
    end
  end

  # Return the string, with "educated" curly quote HTML entities.
  #
  def educate_quotes(str)
    # normalize html
    str = str.dup
    # Special case if the very first character is a quote followed by
    # punctuation at a non-word-break. Close the quotes by brute
    # force:
    str.gsub!(SQ_PUNCT_START_RE, entity(:single_right_quote))
    str.gsub!(DQ_PUNCT_START_RE, entity(:double_right_quote))

    # Special case for double sets of quotes, e.g.:
    #   <p>He said, "'Quoted' words in a larger quote."</p>
    str.gsub!(DQ_SQ_OPEN_RE, "#{entity(:double_left_quote)}#{entity(:single_left_quote)}")
    str.gsub!(SQ_DQ_OPEN_RE, "#{entity(:single_left_quote)}#{entity(:double_left_quote)}")

    # Special case for decade abbreviations (the '80s):
    str.gsub!(DECADE_RE, entity(:single_right_quote))

    dec_dashes = "#{entity(:en_dash)}|#{entity(:em_dash)}"
    sq_open_re =
      if dec_dashes == DEFAULT_DEC_DASHES
        DEFAULT_SQ_OPEN_RE
      else
        /(\s|&nbsp;|=|--|&[mn]dash;|#{dec_dashes}|&#x201[34];)'(?=\w)/
      end
    dq_open_re =
      if dec_dashes == DEFAULT_DEC_DASHES
        DEFAULT_DQ_OPEN_RE
      else
        /(\s|&nbsp;|=|--|&[mn]dash;|#{dec_dashes}|&#x201[34];)"(?=\w)/
      end

    # Get most opening single quotes:
    str.gsub!(sq_open_re, '\1' + entity(:single_left_quote))

    # Single closing quotes:
    str.gsub!(SQ_CLOSE_1_RE, '\1' + entity(:single_right_quote))
    str.gsub!(SQ_CLOSE_2_RE, entity(:single_right_quote) + '\1')

    # Any remaining single quotes should be opening ones:
    str.gsub!(/'/, entity(:single_left_quote))

    # Get most opening double quotes:
    str.gsub!(dq_open_re, '\1' + entity(:double_left_quote))

    # Double closing quotes:
    str.gsub!(DQ_CLOSE_1_RE, '\1' + entity(:double_right_quote))
    str.gsub!(DQ_CLOSE_2_RE, entity(:double_right_quote) + '\1')

    # Any remaining quotes should be opening ones:
    str.gsub!(/"/, entity(:double_left_quote))

    str
  end

  # Return the string, with each RubyPants HTML entity translated to
  # its ASCII counterpart.
  #
  # Note: This is not reversible (but exactly the same as in SmartyPants)
  #
  def stupefy_entities(str)
    new_str = str.dup

    {
      en_dash: "-",
      em_dash: "--",
      single_left_quote: "'",
      single_right_quote: "'",
      double_left_quote: '"',
      double_right_quote: '"',
      ellipsis: "...",
    }.each { |k, v| new_str.gsub!(/#{entity(k)}/, v) }

    new_str
  end

  # Return an array of the tokens comprising the string. Each token is
  # either a tag (possibly with nested, tags contained therein, such
  # as <tt><a href="<MTFoo>"></tt>, or a run of text between
  # tags. Each element of the array is a two-element array; the first
  # is either :tag or :text; the second is the actual value.
  #
  # Based on the <tt>_tokenize()</tt> subroutine from Brad Choate's
  # MTRegex plugin.  <http://www.bradchoate.com/past/mtregex.php>
  #
  # This is actually the easier variant using tag_soup, as used by
  # Chad Miller in the Python port of SmartyPants.
  #
  def tokenize
    tokens = []
    prev_end = 0

    scan(TAG_SOUP_RE) do
      tokens << [:text, $1] if $1 != ""
      tokens << [:tag, $2]
      prev_end = $~.end(0)
    end

    tokens << [:text, self[prev_end..-1]] if prev_end < size
    tokens
  end

  def default_entities
    DEFAULT_ENTITIES.dup
  end

  def entity(key)
    @entities[key]
  end
end
