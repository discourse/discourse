# frozen_string_literal: true

require 'spec_helper'

describe Onebox::Engine::TwitchClipsOnebox do

  it "has the iframe with the correct channel" do
    expect(Onebox.preview('https://clips.twitch.tv/FunVastGalagoKlappa').to_s).to match(/<iframe src="\/\/clips\.twitch\.tv\/embed\?clip=FunVastGalagoKlappa/)

  end

end
