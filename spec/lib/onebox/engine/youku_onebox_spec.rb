# frozen_string_literal: true

RSpec.describe Onebox::Engine::YoukuOnebox do
  before do
    stub_request(:get, "http://v.youku.com/v_show/id_XNjM3MzAxNzc2.html").to_return(
      status: 200,
      body: onebox_response("youku"),
      headers: {
        content_type: "text/html",
      },
    )

    stub_request(:get, "http://v.youku.com/player/getPlayList/VideoIDS/XNjM3MzAxNzc2").to_return(
      status: 200,
      body: onebox_response("youku-meta"),
      headers: {
        content_type: "text/html",
      },
    )
  end

  it "returns embed as the placeholder" do
    html = Onebox.preview("http://v.youku.com/v_show/id_XNjM3MzAxNzc2.html").placeholder_html
    expect(html).to match(/embed/)
  end
end
