require 'open-uri'

desc 'Creates the integration fixtures. Requires a development instance running.'
task 'integration:create_fixtures' => :environment do

  fixtures = {
    discovery: ["/latest.json", "/categories.json", "/c/bug/l/latest.json"],
    topic: ["/t/280.json"],
    user: ["/u/eviltrout.json",
           "/user_actions.json",
           "/topics/created-by/eviltrout.json"],
    static: ["/faq", '/tos', '/privacy'],
    unknown: ['/404-body']
  }

  fixtures.each do |type, urls|

    filename = "#{Rails.root}/test/javascripts/fixtures/#{type}_fixtures.js"

    content = "/*jshint maxlen:10000000 */\nexport default {\n"
    urls.each do |url|

      http_result = fake_xhr("http://localhost:3000#{url}")

      # If the result is not JSON, convert it to JSON
      begin
        parsed = ::JSON.parse(http_result)
      rescue
        http_result = http_result.to_json
      end
      content << "\"#{url}\": #{http_result},\n"

    end
    content << "};\n"

    File.write(filename, content)
  end

end

def fake_xhr(url)
  uri = URI(url)

  result = nil
  Net::HTTP.start(uri.host, uri.port) do |http|
    request = Net::HTTP::Get.new uri
    request.add_field "X-Requested-With", "XMLHttpRequest"
    response = http.request(request)
    result = response.body.force_encoding("UTF-8")
  end

  result

end
