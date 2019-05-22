# frozen_string_literal: true

require 'spec_helper'

describe Onebox::Engine::TwitchVideoOnebox do

  it "has the iframe with the correct channel" do
    expect(Onebox.preview('https://www.twitch.tv/videos/140675974').to_s).to match(/<iframe src="\/\/player\.twitch\.tv\/\?video=v140675974/)

  end

end
