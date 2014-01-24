module HTMLSpecHelper
  def fake(uri, response, verb = :get)
    FakeWeb.register_uri(verb, uri, response: header(response))
  end

  def header(html)
    "HTTP/1.1 200 OK\n\n#{html}"
  end

  def onebox_view(html)
    %|<div class="onebox">#{html}</div>|
  end

  def response(file)
    file = File.join("spec", "fixtures", "#{file}.response")
    File.exists?(file) ? File.read(file) : ""
  end
end
