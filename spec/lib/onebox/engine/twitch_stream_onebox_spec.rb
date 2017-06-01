require 'spec_helper'

describe Onebox::Engine::TwitchStreamOnebox do

  it "has the iframe with the correct channel" do
    expect(Onebox.preview('https://www.twitch.tv/theduckie908').to_s).to match(/<iframe src="\/\/player\.twitch\.tv\/\?channel=theduckie908/)

  end

end
