# frozen_string_literal: true

require 'spec_helper'

describe Onebox::Engine::TwitchStreamOnebox do

  it "has the iframe with the correct channel" do
    expect(Onebox.preview('https://www.twitch.tv/theduckie908').to_s).to match(/<iframe src="\/\/player\.twitch\.tv\/\?channel=theduckie908/)

  end

  it "works in the twitch new interface/url" do
    expect(Onebox.preview('https://go.twitch.tv/admiralbulldog').to_s).to match(/<iframe src="\/\/player\.twitch\.tv\/\?channel=admiralbulldog/)

  end

end
