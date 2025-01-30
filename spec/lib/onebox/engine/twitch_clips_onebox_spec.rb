# frozen_string_literal: true

RSpec.describe Onebox::Engine::TwitchClipsOnebox do
  let(:hostname) { Discourse.current_hostname }
  let(:options) { { hostname: hostname } }
  let(:expected) do
    %r{<iframe src="https://clips\.twitch\.tv/embed\?clip=CheerfulAliveFoxUWot-3FacBI-00c45Ptvd&amp;parent=#{hostname}}
  end

  it "has the iframe with the correct channel" do
    expect(
      Onebox.preview("https://clips.twitch.tv/CheerfulAliveFoxUWot-3FacBI-00c45Ptvd", options).to_s,
    ).to match(expected)
  end

  it "handles all possible clips urls" do
    expect(
      Onebox.preview(
        "https://www.twitch.tv/gorgc/clip/CheerfulAliveFoxUWot-3FacBI-00c45Ptvd?filter=clips&range=7d&sort=time",
        options,
      ).to_s,
    ).to match(expected)

    expect(
      Onebox.preview(
        "https://clips.twitch.tv/embed?clip=CheerfulAliveFoxUWot-3FacBI-00c45Ptvd&parent=www.example.com",
        options,
      ).to_s,
    ).to match(expected)

    expect(
      Onebox.preview("https://clips.twitch.tv/CheerfulAliveFoxUWot-3FacBI-00c45Ptvd", options).to_s,
    ).to match(expected)
  end
end
