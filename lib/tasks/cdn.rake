# cdn related tasks
#
desc 'pre-stage assets on cdn'
task 'assets:prestage' => :environment do |t|
  require "net/https"
  require "uri"

  def get_assets(path)
    a = Dir.glob("#{Rails.root}/public/assets/#{path}*").map do |f|
      if f =~ /[a-f0-9]{16}\.(css|js)$/
        "/assets/#{path}#{f.split('/')[-1]}"
      end
    end.compact
  end
  
  # pre-stage css/js only for now
  a = get_assets("locales/") + get_assets("")
  puts "pre staging: #{a.join(' ')}"

  # makes testing simpler leaving this here
  config = YAML::load(File.open("#{Rails.root}/config/cdn.yml"))

  start = Time.now

  uri = URI.parse("https://client.cdn77.com/api/prefetch")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Post.new(uri.request_uri)
  request.set_form_data(
    "id" => config["id"],
    "login" => config["login"],
    "passwd" => config["password"],
    "json" => {"prefetch_paths" => a.join("\n")}.to_json
  )

  response = http.request(request)
  json = JSON.parse(response.body)
  if json["status"] != "ok"
    raise "Failed to pre-stage"
  end
  puts "Done (took: #{((Time.now - start) * 1000.0).to_i}ms)"

end
