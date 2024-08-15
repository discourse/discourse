require "bundler/inline"
require "yaml"
gemfile do
  source "https://rubygems.org"
  gem "faraday", require: true
end

index_topic_id = 308_036

def slugify(title)
  title.downcase.gsub(/[^a-z0-9]+/, "-")
end

client =
  Faraday.new(url: "https://meta.discourse.org") do |conn|
    conn.request :url_encoded
    conn.response :json, content_type: "application/json"
    conn.response :raise_error
    conn.adapter Faraday.default_adapter
  end

topic_info = client.get("/t/#{index_topic_id}.json?include_raw=1").body
raw = topic_info["post_stream"]["posts"].first["raw"]

current_section = nil
current_section_i = 0
current_topic_i = 1
dir = nil

id_map = []

raw.each_line do |line|
  puts "line: #{line}"
  if current_section && match = line.strip.match(/\A\* (.+): (.+)\z/)
    puts "fetching #{current_section}: #{match[1]}"
    short_title = match[1]
    next if !match[2].include?("meta.discourse.org/t/")
    topic_id = match[2][%r{/(\d+)}, 1].to_i
    puts "fetching topic #{topic_id}"
    topic_info = client.get("/t/#{topic_id}.json?include_raw=1").body
    title = topic_info["title"]
    raw = topic_info["post_stream"]["posts"].first["raw"]

    upload_i = 1
    raw =
      raw.gsub(%r{![^\]]+\]\((upload://[^)]+)\)}) do |match|
        filename_with_protocol = $1
        filename = $1.sub("upload://", "")
        # puts "Filename is ", filename
        url = "https://meta.discourse.org/uploads/short-url/#{filename}"
        print "downloading #{url}..."
        response = Faraday.get(url)
        if response.status != 302
          puts "failed"
          next match
        end
        # raise "unexpected status #{response.status}" if response.status != 302
        url = response.headers["Location"]
        response = Faraday.get(url)
        data = response.body

        local_name = "assets/#{slugify(short_title)}-#{upload_i}#{File.extname(filename)}"
        upload_i += 1

        File.write(local_name, data)
        puts " done"
        match.gsub(filename_with_protocol, "/#{local_name}")
      end

    doc_id = slugify(short_title)[0..45]
    File.write("#{dir}/#{format("%02d", current_topic_i)}-#{slugify(short_title)}.md", <<~MD)
      #{YAML.dump({ "title" => title, "short_title" => short_title, "id" => doc_id })}
      ---
      #{raw}
    MD
    id_map << [doc_id, topic_id]
    current_topic_i += 1
  elsif match = line.match(/\A## (.+)\n/)
    current_section = match[1]
    current_section_i += 1

    dir = "#{__dir__}/docs/#{format("%02d", current_section_i)}-#{slugify(current_section)}"
    FileUtils.mkdir_p(dir)
    File.write("#{dir}/index.md", <<~MD)
      #{YAML.dump({ "title" => current_section })}
      ---
    MD

    current_topic_i = 1
    puts "new section #{current_section}"
  end
end

File.write(
  "#{__dir__}/scrape_map.csv",
  id_map.map { |id, topic_id| "#{id},#{topic_id}" }.join("\n")
)
