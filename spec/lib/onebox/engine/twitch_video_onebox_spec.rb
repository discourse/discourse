# frozen_string_literal: true

RSpec.describe Onebox::Engine::TwitchVideoOnebox do
  let(:hostname) { Discourse.current_hostname }
  let(:options) { { hostname: hostname } }

  it "has the iframe with the correct channel" do
    expect(Onebox.preview("https://www.twitch.tv/videos/140675974", options).to_s).to match(
      %r{<iframe src="https://player\.twitch\.tv/\?video=v140675974&amp;parent=#{hostname}},
    )
  end
end
