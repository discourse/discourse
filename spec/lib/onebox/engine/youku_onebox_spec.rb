# frozen_string_literal: true

require "rails_helper"
require "onebox_helper"

describe Onebox::Engine::YoukuOnebox do
  before do
    FakeWeb.register_uri(:get, 'http://v.youku.com/v_show/id_XNjM3MzAxNzc2.html', body: onebox_response('youku'), content_type: 'text/html')
    FakeWeb.register_uri(:get, 'http://v.youku.com/player/getPlayList/VideoIDS/XNjM3MzAxNzc2', body: onebox_response('youku-meta'), content_type: 'text/html')
  end

  it 'returns embed as the placeholder' do
    expect(Onebox.preview('http://v.youku.com/v_show/id_XNjM3MzAxNzc2.html')
        .placeholder_html).to match(/embed/)
  end
end
