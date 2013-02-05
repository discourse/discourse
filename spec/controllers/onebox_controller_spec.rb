require 'spec_helper'

describe OneboxController do

  it 'asks the oneboxer for the preview' do
    Oneboxer.expects(:preview).with('http://google.com')
    xhr :get, :show, url: 'http://google.com'
  end

  it 'invalidates the cache if refresh is passed' do
    Oneboxer.expects(:invalidate).with('http://google.com')
    xhr :get, :show, url: 'http://google.com', refresh: true
  end

end
