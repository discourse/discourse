module HTMLSpecHelper
  def fake(uri, response, verb = :get)
    FakeWeb.register_uri(verb, uri, response: header(response))
  end

  def header(html)
    "HTTP/1.1 200 OK\n\n#{body(html)}"
  end

  def body(html)
    "<!DOCTYPE html>\n<html><body>#{html}</body></html>\n"
  end

  def onebox_view(html)
    %|<div class="onebox">#{html}</div>|
  end
end
 