EMOJI_LIST_URL = "http://unicode.org/emoji/charts/full-emoji-list.html"
EMOJI_KEYWORDS_URL = "https://raw.githubusercontent.com/muan/emojilib/master/emojis.json"

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
             .gsub(/_fe0f$/i, "")

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

    next unless emojis[code]

    apple = cell_to_image(cells[4])
    google = cell_to_image(cells[5])
    twitter = cell_to_image(cells[6])
    one = cell_to_image(cells[7])
    windows = cell_to_image(cells[9])

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

def write_emojis(emojis, aliases, style, folder)
  path = "public/images/emoji/#{folder}/"

  FileUtils.rm_f Dir.glob("#{path}/*")

  puts folder

  emojis.values.each do |emoji|
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
end
