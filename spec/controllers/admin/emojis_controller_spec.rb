require "rails_helper"

describe Admin::EmojisController do

  let(:custom_emoji) do
    Emoji.new("/path/to/hello").tap do |e|
      e.name = "hello"
      e.url = "/url/to/hello.png"
    end
  end

  let(:custom_emoji2) do
    Emoji.new("/path/to/hello2").tap do |e|
      e.name = "hello2"
      e.url = "/url/to/hello2.png"
    end
  end

  context "when logged in" do
    let!(:user) { log_in(:admin) }

    context ".index" do
      it "returns a list of custom emojis" do
        Emoji.expects(:custom).returns([custom_emoji])
        get :index, format: :json
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json[0]["name"]).to eq(custom_emoji.name)
        expect(json[0]["url"]).to eq(custom_emoji.url)
      end
    end
  end

end
