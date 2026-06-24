# frozen_string_literal: true

class TopicOgImageGenerator
  OG_WIDTH = 1200
  OG_HEIGHT = 630
  MAX_TITLE_LENGTH = 100
  MAX_TITLE_LINES = 2
  TITLE_LINE_CHARS = 34
  LOGO_HEIGHT = 100
  LOGO_WIDTH = 300
  AVATAR_SIZE = 72
  SIDE_MARGIN = 80
  FONT_FAMILY = "sans-serif"

  # OG images are embedded in public topic pages for external crawlers and
  # link previewers, so we must not generate them for content that is not
  # publicly visible (PMs or topics in read-restricted categories).
  def self.eligible?(topic)
    return false if topic.nil?
    return false if SiteSetting.login_required
    return false if topic.private_message?
    return false if topic.category&.read_restricted?
    true
  end

  def initialize(topic)
    @topic = topic
  end

  # Generates the OG image, persists as an Upload, and returns it (or nil on failure).
  def generate
    svg = build_svg
    png = render_png(svg)
    return nil if png.nil?
    create_upload(png)
  end

  # Renders the OG image to PNG bytes without persisting an Upload. Used by the
  # admin preview endpoint to avoid producing orphaned uploads on every click.
  def generate_bytes
    svg = build_svg
    render_png(svg)
  end

  private

  def build_svg
    title = truncated_title
    category_name = @topic.category&.name || ""
    category_color = @topic.category&.color || "888888"
    like_count = @topic.like_count || 0
    posts_count = [@topic.posts_count - 1, 0].max
    read_time = calculate_read_time
    colors = fetch_colors
    logo_upload = SiteSetting.logo.presence || SiteSetting.logo_small
    logo_data_uri = fetch_as_data_uri(logo_upload&.url)

    title_lines = word_wrap(title, TITLE_LINE_CHARS)
    truncated = title_lines.length > MAX_TITLE_LINES
    display_lines = title_lines.take(MAX_TITLE_LINES)
    if truncated
      last = display_lines.last
      display_lines[-1] = (
        if last.length > TITLE_LINE_CHARS - 1
          "#{last[0...TITLE_LINE_CHARS - 1]}…"
        else
          "#{last}…"
        end
      )
    end

    title_start_y = 190
    title_end_y = title_start_y + ((display_lines.length - 1) * 58)
    author_y = title_end_y + 55

    author = @topic.user
    avatar_data_uri =
      author ? fetch_as_data_uri(author.avatar_template_url.gsub("{size}", "120")) : nil
    username = author&.username
    created_at = @topic.created_at&.strftime("%b %-d, %Y")

    logo_y = OG_HEIGHT - 60 - LOGO_HEIGHT
    stats_y = OG_HEIGHT - 60 - (LOGO_HEIGHT / 2) + 15

    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="#{OG_WIDTH}" height="#{OG_HEIGHT}" viewBox="0 0 #{OG_WIDTH} #{OG_HEIGHT}">
        <defs>
          <clipPath id="avatar-clip">
            <rect x="#{SIDE_MARGIN}" y="#{author_y}" width="#{AVATAR_SIZE}" height="#{AVATAR_SIZE}" rx="20"/>
          </clipPath>
        </defs>

        <!-- Background -->
        <rect width="#{OG_WIDTH}" height="#{OG_HEIGHT}" fill="##{colors[:secondary]}"/>

        <!-- Top accent bar -->
        <rect width="#{OG_WIDTH}" height="18" fill="##{colors[:tertiary]}"/>

        <!-- Category pill -->
        #{category_pill_svg(category_name, category_color, SIDE_MARGIN, 60)}

        <!-- Title -->
        #{title_svg(display_lines, colors[:primary], SIDE_MARGIN, title_start_y)}

        <!-- Author -->
        #{author_svg(avatar_data_uri, username, created_at, colors, SIDE_MARGIN, author_y)}

        <!-- Site logo -->
        #{logo_svg(logo_data_uri, logo_upload, SIDE_MARGIN, logo_y)}

        <!-- Stats -->
        #{stats_svg(like_count, posts_count, read_time, colors, OG_WIDTH - SIDE_MARGIN, stats_y)}

        <!-- Site domain -->
        #{domain_svg(colors, OG_WIDTH - SIDE_MARGIN, 88)}
      </svg>
    SVG
  end

  # Category pill size. Character-width heuristic is approximate and tuned for a
  # generic sans-serif at font-size 24; long / non-Latin names are truncated
  # here and the rect is capped to the canvas width so we never render past the
  # right edge. Non-Latin glyphs may not fill the pill perfectly but will stay
  # visually contained.
  def category_pill_svg(name, color, x, y)
    return "" if name.blank?

    pill_padding = 16
    max_pill_width = OG_WIDTH - (2 * SIDE_MARGIN)
    pill_width = [name.length * 14.5 + (pill_padding * 2), max_pill_width].min
    max_name_chars = [((pill_width - (pill_padding * 2)) / 14.5).floor, 1].max
    display_name = name.length > max_name_chars ? "#{name[0...[max_name_chars - 1, 1].max]}…" : name

    <<~SVG
      <rect x="#{x}" y="#{y}" width="#{pill_width}" height="40" rx="6" fill="##{color}" fill-opacity="0.15"/>
      <text x="#{x + pill_padding}" y="#{y + 30}" font-family="#{FONT_FAMILY}" font-size="24" font-weight="600" fill="##{color}">#{escape_xml(display_name)}</text>
    SVG
  end

  def title_svg(lines, primary_color, x, start_y)
    lines
      .each_with_index
      .map do |line, i|
        y = start_y + (i * 68)
        %(<text x="#{x}" y="#{y}" font-family="#{FONT_FAMILY}" font-size="62" font-weight="700" fill="##{primary_color}">#{escape_xml(line)}</text>)
      end
      .join("\n    ")
  end

  def author_svg(avatar_data_uri, username, created_at, colors, x, y)
    return "" if username.blank?

    parts = []

    parts << <<~SVG.strip if avatar_data_uri.present?
        <image x="#{x}" y="#{y}" width="#{AVATAR_SIZE}" height="#{AVATAR_SIZE}" href="#{avatar_data_uri}" clip-path="url(#avatar-clip)"/>
        <rect x="#{x}" y="#{y}" width="#{AVATAR_SIZE}" height="#{AVATAR_SIZE}" rx="20" fill="none" stroke="##{colors[:secondary]}" stroke-opacity="0.1" stroke-width="1"/>
      SVG

    text_x = avatar_data_uri.present? ? x + AVATAR_SIZE + 32 : x
    text_y = y + (AVATAR_SIZE / 2) + 8

    author_text = username
    author_text = "#{author_text}  ·  #{created_at}" if created_at.present?

    parts << %(<text x="#{text_x}" y="#{text_y}" font-family="#{FONT_FAMILY}" font-size="34" font-weight="400" fill="##{colors[:primary]}" opacity="0.6">#{escape_xml(author_text)}</text>)

    parts.join("\n    ")
  end

  def logo_svg(logo_data_uri, upload, x, y)
    return "" if logo_data_uri.blank?

    orig_w = upload&.width.to_f
    orig_h = upload&.height.to_f

    if orig_w > 0 && orig_h > 0
      scale = [LOGO_WIDTH.to_f / orig_w, LOGO_HEIGHT.to_f / orig_h].min
      w = (orig_w * scale).round
      h = (orig_h * scale).round
    else
      w = LOGO_WIDTH
      h = LOGO_HEIGHT
    end

    offset_y = y + ((LOGO_HEIGHT - h) / 2)

    <<~SVG
      <image x="#{x}" y="#{offset_y}" width="#{w}" height="#{h}" href="#{logo_data_uri}"/>
    SVG
  end

  def stats_svg(likes, replies, read_time, colors, right_x, y)
    items = []
    items << "#{read_time}m read" if read_time && read_time >= 1
    items << "#{replies} #{replies == 1 ? "reply" : "replies"}" if replies > 0
    items << "#{likes} #{likes == 1 ? "like" : "likes"}" if likes > 0
    return "" if items.empty?

    text = items.join("  ·  ")
    %(<text x="#{right_x}" y="#{y}" font-family="#{FONT_FAMILY}" font-size="30" font-weight="400" fill="##{colors[:primary]}" opacity="0.5" text-anchor="end">#{escape_xml(text)}</text>)
  end

  def domain_svg(colors, right_x, y)
    domain = Discourse.current_hostname
    return "" if domain.blank?

    %(<text x="#{right_x}" y="#{y}" font-family="#{FONT_FAMILY}" font-size="30" font-weight="400" fill="##{colors[:primary]}" opacity="0.5" text-anchor="end">#{escape_xml(domain)}</text>)
  end

  def calculate_read_time
    return nil if @topic.word_count.to_i <= 0 || SiteSetting.read_time_word_count.to_i <= 0

    min_post_read_time = 4.0
    [
      @topic.word_count / SiteSetting.read_time_word_count,
      @topic.posts_count * min_post_read_time / 60,
    ].max.ceil
  end

  def truncated_title
    title = @topic.title || ""
    title.length > MAX_TITLE_LENGTH ? "#{title[0...MAX_TITLE_LENGTH - 1]}…" : title
  end

  # Wraps by whitespace when possible; falls back to grapheme-boundary splits
  # for runs longer than max_chars (e.g. CJK titles with no spaces, long URLs)
  # so the title doesn't overflow the canvas.
  def word_wrap(text, max_chars)
    lines = []
    current_line = +""

    text.split.each do |word|
      chunks = word.length > max_chars ? split_chunks(word, max_chars) : [word]

      chunks.each do |chunk|
        if current_line.empty?
          current_line = chunk.dup
        elsif (current_line.length + 1 + chunk.length) <= max_chars
          current_line << " " << chunk
        else
          lines << current_line
          current_line = chunk.dup
        end
      end
    end

    lines << current_line if current_line.present?
    lines
  end

  def split_chunks(word, max_chars)
    word.grapheme_clusters.each_slice(max_chars).map(&:join)
  end

  def fetch_colors
    scheme = Theme.find_by(id: SiteSetting.default_theme_id)&.color_scheme
    if scheme
      resolved = scheme.resolved_colors
      {
        primary: resolved["primary"] || "000000",
        secondary: resolved["secondary"] || "ffffff",
        tertiary: resolved["tertiary"] || "0088cc",
      }
    else
      base = ColorScheme.base_colors
      {
        primary: base["primary"] || "000000",
        secondary: base["secondary"] || "ffffff",
        tertiary: base["tertiary"] || "0088cc",
      }
    end
  end

  def fetch_as_data_uri(url)
    return nil if url.blank?

    absolute_url = get_absolute_url(url)
    tmp =
      FileHelper.download(
        absolute_url,
        max_file_size: 1.megabyte,
        tmp_file_name: "og_image_asset",
        follow_redirect: true,
        read_timeout: 10,
      )
    return nil if tmp.nil?

    path =
      (
        begin
          URI.parse(absolute_url).path
        rescue StandardError
          absolute_url
        end
      )
    content_type = MiniMime.lookup_by_filename(path)&.content_type || "image/png"
    encoded = Base64.strict_encode64(tmp.read)
    "data:#{content_type};base64,#{encoded}"
  rescue => e
    Discourse.warn("Failed to fetch image for OG generation", url: url, error: e.message)
    nil
  ensure
    tmp&.close
    tmp&.unlink if tmp.respond_to?(:unlink)
  end

  def get_absolute_url(url)
    return url if url.start_with?("http")
    return "https:#{url}" if url.start_with?("//")
    "#{Discourse.base_url_no_prefix}#{url}"
  end

  def escape_xml(text)
    text
      .to_s
      .gsub("&", "&amp;")
      .gsub("<", "&lt;")
      .gsub(">", "&gt;")
      .gsub("'", "&apos;")
      .gsub('"', "&quot;")
  end

  def render_png(svg)
    Dir.mktmpdir("topic_og") do |dir|
      svg_path = File.join(dir, "og.svg")
      png_path = File.join(dir, "og.png")

      File.write(svg_path, svg)

      # Rasterize with rsvg-convert (ImageMagick's own configured SVG delegate)
      # rather than `convert`/`magick`: ImageMagick's internal SVG renderer can't
      # resolve generic font families like "sans-serif" and raises "unable to read
      # font", whereas rsvg-convert resolves them via fontconfig.
      Discourse::Utils.execute_command(
        "nice",
        "-n",
        "10",
        "rsvg-convert",
        "--width",
        OG_WIDTH.to_s,
        "--height",
        OG_HEIGHT.to_s,
        "--background-color",
        "none",
        "--output",
        png_path,
        svg_path,
        timeout: 20_000,
      )

      return nil unless File.exist?(png_path)
      FileHelper.optimize_image!(png_path)
      File.binread(png_path)
    end
  rescue Discourse::Utils::CommandError => e
    Discourse.warn("Failed to render topic OG image", topic_id: @topic.id, error: e.message)
    nil
  end

  def create_upload(png_bytes)
    Tempfile.create(["topic-og-#{@topic.id}", ".png"], binmode: true) do |tmp|
      tmp.write(png_bytes)
      tmp.rewind
      return(
        UploadCreator.new(
          tmp,
          "topic-og-#{@topic.id}.png",
          type: "topic_og_image",
          skip_validations: true,
        ).create_for(Discourse.system_user.id)
      )
    end
  end
end
