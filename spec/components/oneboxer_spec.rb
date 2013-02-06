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

  
  before do
    Oneboxer.add_onebox DummyOnebox
    @dummy_onebox_url = "http://dummy.localhost/dummy-object"
  end

  it 'should have matchers set up by default' do
    Oneboxer.matchers.should be_present
  end

  context 'find onebox for url' do

    it 'returns blank with an unknown url' do
      Oneboxer.onebox_for_url('http://asdfasdfasdfasdf.asdf').should be_blank
    end

    it 'returns something when matched' do
      Oneboxer.onebox_for_url(@dummy_onebox_url).should be_present
    end

    it 'returns an instance of our class when matched' do
      Oneboxer.onebox_for_url(@dummy_onebox_url).kind_of?(DummyOnebox).should be_true
    end

  end

  context 'without caching' do  
    it 'calls the onebox method of our matched class' do
      Oneboxer.onebox_nocache(@dummy_onebox_url).should == 'dummy!'
    end
  end

  context 'with caching' do

    context 'initial cache is empty' do

      it 'has no OneboxRender records' do
        OneboxRender.count.should == 0
      end

      it 'calls the onebox_nocache method if there is no cache record yet' do
        Oneboxer.expects(:onebox_nocache).with(@dummy_onebox_url).once
        Oneboxer.onebox(@dummy_onebox_url)
      end
    end

    context 'caching result' do
      before do
        @post = Fabricate(:post)
        @result = Oneboxer.onebox(@dummy_onebox_url, post_id: @post.id)
        @onebox_render = OneboxRender.where(url: @dummy_onebox_url).first
      end

      it "returns the correct result" do
        @result.should == 'dummy!'
      end

      it "created a OneboxRender record with the url" do
        @onebox_render.should be_present
      end

      it "created a OneboxRender record with the url" do
        @onebox_render.url.should == @dummy_onebox_url        
      end

      it "associated the render with a post" do
        @onebox_render.posts.should == [@post]
      end

      it "has an expires_at value" do
        @onebox_render.expires_at.should be_present
      end

      it "doesn't call onebox_nocache on a cache hit" do
        Oneboxer.expects(:onebox_nocache).never
        Oneboxer.onebox(@dummy_onebox_url).should == 'dummy!'
      end

      context 'invalidating cache' do

        it "deletes the onebox render" do
          Oneboxer.expects(:onebox_nocache).once.returns('new cache value!')
          Oneboxer.onebox(@dummy_onebox_url, invalidate_oneboxes: true).should == 'new cache value!'
        end

      end

    end

  end

  context 'each_onebox_link' do

    before do
      @html = "<a href='http://discourse.org' class='onebox'>Discourse Link</a>"
    end

    it 'yields each url and element when given a string' do
      result = Oneboxer.each_onebox_link(@html) do |url, element|
        element.is_a?(Hpricot::Elem).should be_true
        url.should == 'http://discourse.org'
      end
      result.kind_of?(Hpricot::Doc).should be_true
    end

    it 'yields each url and element when given a doc' do
      doc = Hpricot(@html)
      Oneboxer.each_onebox_link(doc) do |url, element|
        element.is_a?(Hpricot::Elem).should be_true
        url.should == 'http://discourse.org'
      end
    end    

  end


end

 
