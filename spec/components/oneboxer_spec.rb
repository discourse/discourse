require 'spec_helper'
require 'oneboxer'

describe "Dynamic Oneboxer" do
  class DummyDynamicOnebox < Oneboxer::BaseOnebox
    matcher do
      /^https?:\/\/dummy2.localhost/
    end

    def onebox
      "dummy2!"
    end
  end

  before do
    Oneboxer.add_onebox DummyDynamicOnebox
    @dummy_onebox_url = "http://dummy2.localhost/dummy-object"
  end

  context 'find onebox for url' do

    it 'returns blank with an unknown url' do
      Oneboxer.onebox_for_url('http://asdfasdfasdfasdf.asdf').should be_blank
    end

    it 'returns something when matched' do
      Oneboxer.onebox_for_url(@dummy_onebox_url).should be_present
    end

    it 'returns an instance of our class when matched' do
      Oneboxer.onebox_for_url(@dummy_onebox_url).kind_of?(DummyDynamicOnebox).should be_true
    end

  end

end

describe Oneboxer do

  # A class to help us test
  class DummyOnebox < Oneboxer::BaseOnebox
    matcher /^https?:\/\/dummy.localhost/

    def onebox
      "dummy!"
    end
  end

  let(:dummy_onebox_url) { "http://dummy.localhost/dummy-object" }

  before do
    Oneboxer.add_onebox DummyOnebox
  end

  it 'should have matchers set up by default' do
    Oneboxer.matchers.should be_present
  end

  context 'caching' do

    let(:result) { "onebox result string" }

    context "with invalidate_oneboxes true" do

      it "invalidates the url" do
        Oneboxer.expects(:invalidate).with(dummy_onebox_url)
        Oneboxer.onebox(dummy_onebox_url, invalidate_oneboxes: true)
      end

      it "doesn't render from cache" do
        Oneboxer.expects(:render_from_cache).never
        Oneboxer.onebox(dummy_onebox_url, invalidate_oneboxes: true)
      end

      it "calls fetch and cache" do
        Oneboxer.expects(:fetch_and_cache).returns(result)
        Oneboxer.onebox(dummy_onebox_url, invalidate_oneboxes: true).should == result
      end

    end

    context 'with invalidate_oneboxes false' do

      it "doesn't invalidate the url" do
        Oneboxer.expects(:invalidate).with(dummy_onebox_url).never
        Oneboxer.onebox(dummy_onebox_url, invalidate_oneboxes: false)
      end

      it "returns render_from_cache if present" do
        Oneboxer.expects(:render_from_cache).with(dummy_onebox_url).returns(result)
        Oneboxer.onebox(dummy_onebox_url, invalidate_oneboxes: false).should == result
      end

      it "doesn't call fetch_and_cache" do
        Oneboxer.expects(:render_from_cache).with(dummy_onebox_url).returns(result)
        Oneboxer.expects(:fetch_and_cache).never
        Oneboxer.onebox(dummy_onebox_url, invalidate_oneboxes: false)
      end


      it "calls fetch_and_cache if render from cache is blank" do
        Oneboxer.stubs(:render_from_cache)
        Oneboxer.expects(:fetch_and_cache).returns(result)
        Oneboxer.onebox(dummy_onebox_url, invalidate_oneboxes: false).should == result
      end

    end

  end

  context 'find onebox for url' do

    it 'returns blank with an unknown url' do
      Oneboxer.onebox_for_url('http://asdfasdfasdfasdf.asdf').should be_blank
    end

    it 'returns something when matched' do
      Oneboxer.onebox_for_url(dummy_onebox_url).should be_present
    end

    it 'returns an instance of our class when matched' do
      Oneboxer.onebox_for_url(dummy_onebox_url).kind_of?(DummyOnebox).should be_true
    end

  end

  describe '#nice_host' do
    it 'strips www from the domain' do
      DummyOnebox.new('http://www.cnn.com/thing').nice_host.should eq 'cnn.com'
    end

    it 'respects double TLDs' do
      DummyOnebox.new('http://news.bbc.co.uk/thing').nice_host.should eq 'news.bbc.co.uk'
    end

    it 'returns an empty string if the URL is bogus' do
      DummyOnebox.new('whatever').nice_host.should eq ''
    end

    it 'returns an empty string if the URL unparsable' do
      DummyOnebox.new(nil).nice_host.should eq ''
    end
  end

  context 'without caching' do
    it 'calls the onebox method of our matched class' do
      Oneboxer.onebox_nocache(dummy_onebox_url).should == 'dummy!'
    end
  end

  context 'each_onebox_link' do

    before do
      @html = "<a href='http://discourse.org' class='onebox'>Discourse Link</a>"
    end

    it 'yields each url and element when given a string' do
      result = Oneboxer.each_onebox_link(@html) do |url, element|
        element.is_a?(Nokogiri::XML::Element).should be_true
        url.should == 'http://discourse.org'
      end
      result.kind_of?(Nokogiri::HTML::DocumentFragment).should be_true
    end

    it 'yields each url and element when given a doc' do
      doc = Nokogiri::HTML(@html)
      Oneboxer.each_onebox_link(doc) do |url, element|
        element.is_a?(Nokogiri::XML::Element).should be_true
        url.should == 'http://discourse.org'
      end
    end

  end

  context "apply_onebox" do
    it "is able to nuke wrapping p" do
      doc = Oneboxer.apply "<p><a href='http://bla.com' class='onebox'>bla</p>" do |url, element|
        "<div>foo</div>" if url == "http://bla.com"
      end

      doc.changed? == true
      doc.to_html.should match_html "<div>foo</div>"
    end

    it "is able to do nothing if nil is returned" do
      orig = "<p><a href='http://bla.com' class='onebox'>bla</p>"
      doc = Oneboxer.apply orig do |url, element|
        nil
      end

      doc.changed? == false
      doc.to_html.should match_html orig
    end

    it "does not strip if there is a br in same node" do
      doc = Oneboxer.apply "<p><br><a href='http://bla.com' class='onebox'>bla</p>" do |url, element|
        "<div>foo</div>" if url == "http://bla.com"
      end

      doc.changed? == true
      doc.to_html.should match_html "<p><br><div>foo</div></p>"
    end

  end

end
