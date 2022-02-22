# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::WistiaOnebox do
  before do
    body = '{"version":"1.0","type":"video","html":"\u003ciframe src=\"https://fast.wistia.net/embed/iframe/26sk4lmiix\" title=\"Nice. Video\" allow=\"autoplay; fullscreen\" allowtransparency=\"true\" frameborder=\"0\" scrolling=\"no\" class=\"wistia_embed\" name=\"wistia_embed\" msallowfullscreen width=\"960\" height=\"540\"\u003e\u003c/iframe\u003e\n\u003cscript src=\"https://fast.wistia.net/assets/external/E-v1.js\" async\u003e\u003c/script\u003e","width":960,"height":540,"provider_name":"Wistia, Inc.","provider_url":"https://wistia.com","title":"Nice. ","thumbnail_url":"https://embed-ssl.wistia.com/deliveries/56cacb9a5d6ea04b1f29defaf4b55d1ec979e1b0.jpg?image_crop_resized=960x540","thumbnail_width":960,"thumbnail_height":540,"player_color":"f27398","duration":44.42}'

    stub_request(:get, "https://fast.wistia.com/oembed?embedType=iframe&url=https://support.wistia.com/medias/26sk4lmiix")
      .to_return(status: 200, body: body, headers: {})
  end

  it "returns the right HTML markup for the onebox" do
    expect(Onebox.preview('https://support.wistia.com/medias/26sk4lmiix').to_s.chomp).to eq(
      '<iframe src="https://fast.wistia.net/embed/iframe/26sk4lmiix" width="960" height="540" title="Nice." frameborder="0" allowfullscreen="" seamless="seamless" sandbox="allow-same-origin allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox allow-presentation"></iframe>'
    )
  end

  describe '#placeholder_html' do
    it "returns the right img HTML markup" do
      expect(Onebox.preview('https://support.wistia.com/medias/26sk4lmiix').placeholder_html).to eq(
        "<img src=\"https://embed-ssl.wistia.com/deliveries/56cacb9a5d6ea04b1f29defaf4b55d1ec979e1b0.jpg?image_crop_resized=960x540\" title=\"Nice.\">"
      )
    end
  end
end
