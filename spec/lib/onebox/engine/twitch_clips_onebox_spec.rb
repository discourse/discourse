# frozen_string_literal: true

RSpec.describe Onebox::Engine::TwitchClipsOnebox do
  let(:hostname) { Discourse.current_hostname }
  let(:options) { { hostname: hostname } }

  it "has the iframe with the correct channel" do
    expect(Onebox.preview("https://clips.twitch.tv/FunVastGalagoKlappa", options).to_s).to match(
      %r{<iframe src="https://clips\.twitch\.tv/embed\?clip=FunVastGalagoKlappa&amp;parent=#{hostname}},
    )
  end
end
