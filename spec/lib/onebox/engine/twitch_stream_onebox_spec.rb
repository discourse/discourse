# frozen_string_literal: true

RSpec.describe Onebox::Engine::TwitchStreamOnebox do
  let(:hostname) { Discourse.current_hostname }
  let(:options) { { hostname: hostname } }

  it "has the iframe with the correct channel" do
    expect(Onebox.preview("https://www.twitch.tv/theduckie908", options).to_s).to match(
      %r{<iframe src="https://player\.twitch\.tv/\?channel=theduckie908&amp;parent=#{hostname}},
    )
  end

  it "works in the twitch new interface/url" do
    expect(Onebox.preview("https://go.twitch.tv/admiralbulldog", options).to_s).to match(
      %r{<iframe src="https://player\.twitch\.tv/\?channel=admiralbulldog&amp;parent=#{hostname}},
    )
  end
end
