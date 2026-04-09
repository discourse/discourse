# frozen_string_literal: true

class TopicOgImageGenerator
  OG_WIDTH = 1200
  OG_HEIGHT = 630
  MAX_TITLE_LENGTH = 100
  MAX_TITLE_LINES = 2
  TITLE_LINE_CHARS = 30
  LOGO_HEIGHT = 100
  LOGO_WIDTH = 300
  AVATAR_SIZE = 48

  def initialize(topic)
    @topic = topic
  end

  def generate
    svg = build_svg
    convert_svg_to_png(svg)
  end

  private

  def build_svg
    title = truncated_title
    category_name = @topic.category&.name || ""
    category_color = @topic.category&.color || "888888"
    like_count = @topic.like_count || 0
    posts_count = [@topic.posts_count - 1, 0].max
    colors = fetch_colors
    logo_upload = (SiteSetting.logo.presence || SiteSetting.logo_small)
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

    title_start_y = 183
    title_end_y = title_start_y + ((display_lines.length - 1) * 58)
    author_y = title_end_y + 50

    author = @topic.user
    avatar_data_uri =
      author ? fetch_as_data_uri(author.avatar_template_url.gsub("{size}", "120")) : nil
    username = author&.username
    created_at = @topic.created_at&.strftime("%b %-d, %Y")

    logo_y = OG_HEIGHT - 60 - LOGO_HEIGHT
    stats_y = OG_HEIGHT - 60 - (LOGO_HEIGHT / 2) + 10

    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="#{OG_WIDTH}" height="#{OG_HEIGHT}" viewBox="0 0 #{OG_WIDTH} #{OG_HEIGHT}">
        <defs>
          <style>
            @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&amp;display=swap');
          </style>
          <clipPath id="avatar-clip">
            <rect x="80" y="#{author_y}" width="#{AVATAR_SIZE}" height="#{AVATAR_SIZE}" rx="8"/>
          </clipPath>
        </defs>

        <!-- Background -->
        <rect width="#{OG_WIDTH}" height="#{OG_HEIGHT}" fill="##{colors[:secondary]}"/>

        <!-- Top accent bar -->
        <rect width="#{OG_WIDTH}" height="12" fill="##{colors[:tertiary]}"/>

        <!-- Category pill -->
        #{category_pill_svg(category_name, category_color, 80, 60)}

        <!-- Title -->
        #{title_svg(display_lines, colors[:primary], 80, title_start_y)}

        <!-- Author -->
        #{author_svg(avatar_data_uri, username, created_at, colors, 80, author_y)}

        <!-- Site logo -->
        #{logo_svg(logo_data_uri, logo_upload, 80, logo_y)}

        <!-- Stats -->
        #{stats_svg(like_count, posts_count, colors, OG_WIDTH - 80, stats_y)}
      </svg>
    SVG
  end

  def category_pill_svg(name, color, x, y)
    return "" if name.blank?

    pill_padding = 12
    pill_width = name.length * 12 + pill_padding
    <<~SVG
      <rect x="#{x}" y="#{y}" width="#{pill_width}" height="38" rx="6" fill="##{color}" fill-opacity="0.15"/>
      <text x="#{x + pill_padding}" y="#{y + 26}" font-family="Inter, system-ui, sans-serif" font-size="20" font-weight="600" fill="##{color}">#{escape_xml(name)}</text>
    SVG
  end

  def title_svg(lines, primary_color, x, start_y)
    lines
      .each_with_index
      .map do |line, i|
        y = start_y + (i * 58)
        %(<text x="#{x}" y="#{y}" font-family="Inter, system-ui, sans-serif" font-size="52" font-weight="700" fill="##{primary_color}">#{escape_xml(line)}</text>)
      end
      .join("\n    ")
  end

  def author_svg(avatar_data_uri, username, created_at, colors, x, y)
    return "" if username.blank?

    parts = []

    parts << <<~SVG.strip if avatar_data_uri.present?
        <image x="#{x}" y="#{y}" width="#{AVATAR_SIZE}" height="#{AVATAR_SIZE}" href="#{avatar_data_uri}" clip-path="url(#avatar-clip)"/>
        <rect x="#{x}" y="#{y}" width="#{AVATAR_SIZE}" height="#{AVATAR_SIZE}" rx="8" fill="none" stroke="##{colors[:primary]}" stroke-opacity="0.1" stroke-width="1"/>
      SVG

    text_x = avatar_data_uri.present? ? x + AVATAR_SIZE + 14 : x
    text_y = y + (AVATAR_SIZE / 2) + 6

    author_text = username
    author_text = "#{author_text}  ·  #{created_at}" if created_at.present?

    parts << %(<text x="#{text_x}" y="#{text_y}" font-family="Inter, system-ui, sans-serif" font-size="29" font-weight="400" fill="##{colors[:primary]}" opacity="0.6">#{escape_xml(author_text)}</text>)

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

  def stats_svg(likes, replies, colors, right_x, y)
    parts = []

    if replies > 0
      reply_text = "#{replies} #{replies == 1 ? "reply" : "replies"}"
      parts << reply_text
    end

    if likes > 0
      like_text = "#{likes} #{likes == 1 ? "like" : "likes"}"
      parts << like_text
    end

    return "" if parts.empty?

    stat_text = parts.join("  ·  ")
    <<~SVG
      <text x="#{right_x}" y="#{y}" font-family="Inter, system-ui, sans-serif" font-size="26" font-weight="400" fill="##{colors[:primary]}" opacity="0.5" text-anchor="end">#{escape_xml(stat_text)}</text>
    SVG
  end

  def truncated_title
    title = @topic.title || ""
    title.length > MAX_TITLE_LENGTH ? "#{title[0...MAX_TITLE_LENGTH - 1]}…" : title
  end

  def word_wrap(text, max_chars)
    words = text.split
    lines = []
    current_line = +""

    words.each do |word|
      if current_line.empty?
        current_line = word.dup
      elsif (current_line.length + 1 + word.length) <= max_chars
        current_line << " " << word
      else
        lines << current_line
        current_line = word.dup
      end
    end

    lines << current_line if current_line.present?
    lines
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

    content_type = MiniMime.lookup_by_filename(absolute_url)&.content_type || "image/png"
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

  def convert_svg_to_png(svg)
    Dir.mktmpdir("topic_og") do |dir|
      svg_path = File.join(dir, "og.svg")
      png_path = File.join(dir, "og.png")

      File.write(svg_path, svg)

      Discourse::Utils.execute_command(
        "nice",
        "-n",
        "10",
        "convert",
        "-background",
        "none",
        "-size",
        "#{OG_WIDTH}x#{OG_HEIGHT}",
        svg_path,
        png_path,
        timeout: 20_000,
      )

      return nil unless File.exist?(png_path)

      upload = create_upload(png_path)
      upload
    end
  end

  def create_upload(png_path)
    tmp = File.open(png_path)
    UploadCreator.new(
      tmp,
      "topic-og-#{@topic.id}.png",
      type: "topic_og_image",
      skip_validations: true,
    ).create_for(Discourse.system_user.id)
  ensure
    tmp&.close
  end
end
