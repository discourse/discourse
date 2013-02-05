# cdn related tasks 
#
desc 'pre-stage assets on cdn'
task 'assets:prestage' => :environment do |t|
  require "net/https"
  require "uri"
  
  config = YAML::load(File.open("#{Rails.root}/config/cdn.yml"))

  # pre-stage css/js only for now
  a = Dir.glob("#{Rails.root}/public/assets/*").map do |f|
    if f =~ /[a-f0-9]{16}\.(css|js)$/
      "/assets/#{f.split('/')[-1]}"
    end
  end.compact

  puts "pre staging: #{a.join(' ')}"
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
