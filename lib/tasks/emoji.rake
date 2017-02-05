EMOJI_LIST_URL ||= "http://unicode.org/emoji/charts/full-emoji-list.html"
EMOJI_KEYWORDS_URL ||= "https://raw.githubusercontent.com/muan/emojilib/master/emojis.json"

# until MS release the emoji flags, we'll use custom made flags
WINDOWS_FLAGS ||= Set.new ["1f1e8_1f1f3", "1f1e9_1f1ea", "1f1ea_1f1f8", "1f1eb_1f1f7", "1f1ec_1f1e7", "1f1ee_1f1f9", "1f1ef_1f1f5", "1f1f0_1f1f7", "1f1f7_1f1fa", "1f1fa_1f1f8"]

desc "update emoji images"
task "emoji:update" => :environment do
  emojis = {}

  puts "Loading local emoji database..."
  db = JSON.parse(File.read("lib/emoji/db.json"))
  db["emojis"].each do |e|
    emojis[e["code"].tr("-", "_")] = { name: e["name"] }
  end
  aliases = db["aliases"].to_h

  puts "Enhancing emoji database with emojilib keywords..."
  keywords = JSON.parse(open(EMOJI_KEYWORDS_URL).read)
  keywords.keys.each do |k|
    next unless char = keywords[k]["char"].presence

    code = char.codepoints
               .map { |c| c.to_s(16).rjust(4, "0") }
               .join("_")
               .downcase
               .gsub(/_fe0f$/, "")

    emojis[code] ||= { name: k }
  end

  puts "Retrieving remote emoji list..."
  list = open(EMOJI_LIST_URL).read

  puts "Parsing remote emoji list..."
  doc = Nokogiri::HTML(list)
  doc.css("tr").each do |row|
    cells = row.css("td")
    next if cells.size == 0

    code = cells[1].at_css("a")["name"]

    unless emojis[code]
      code = code.gsub(/_fe0f/, "")
      next unless emojis[code]
    end

    apple = cell_to_image(cells[4])
    google = cell_to_image(cells[5])
    twitter = cell_to_image(cells[6])
    one = cell_to_image(cells[7])

    if WINDOWS_FLAGS.include?(code)
      windows = custom_windows_flag(code)
    else
      windows = cell_to_image(cells[11])
    end

    if apple.blank? || google.blank? || twitter.blank? || one.blank? || windows.blank?
      emojis.delete(code)
      next
    end

    emojis[code][:apple] = apple
    emojis[code][:google] = google
    emojis[code][:twitter] = twitter
    emojis[code][:one] = one
    emojis[code][:windows] = windows
  end

  puts "Writing emojis..."
  write_emojis(emojis, aliases, :apple, "apple")
  write_emojis(emojis, aliases, :google, "google")
  write_emojis(emojis, aliases, :twitter, "twitter")
  write_emojis(emojis, aliases, :one, "emoji_one")
  write_emojis(emojis, aliases, :windows, "win10")

  puts "Updating db.json..."
  db = {
    "emojis" => emojis.keys.map { |k| { "code" => k.tr("_", "-"), "name" => emojis[k][:name] } },
    "aliases" => aliases,
  }

  File.write("lib/emoji/db.json", JSON.pretty_generate(db))

  puts "Done!"
end

def cell_to_image(cell)
  return unless img = cell.at_css("img")
  Base64.decode64(img["src"][/base64,(.+)$/, 1])
end

def custom_windows_flag(code)
  name = code.upcase.tr("_", "-")
  open("https://github.com/discourse/discourse-emoji-extractor/raw/master/win10/72x72/windows_#{name}.png").read
end

def write_emojis(emojis, aliases, style, folder)
  path = "public/images/emoji/#{folder}"

  # Uncomment to recreate all emojis
  # FileUtils.rm_f Dir.glob("#{path}/*")

  puts folder

  emojis.values.each do |emoji|
    next if emoji[style].nil?

    write_emoji("#{path}/#{emoji[:name]}.png", emoji[style])
    if aliases[emoji[:name]]
      aliases[emoji[:name]].each do |new_name|
        write_emoji("#{path}/#{new_name}.png", emoji[style])
      end
    end
  end

  puts
end

def write_emoji(path, emoji)
    open(path, "wb") { |f| f << emoji }
    `pngout #{path}`
    putc "."
ensure
  raise "Failed to write emoji: #{path}" if File.exists?(path) && !File.size?(path)
end
