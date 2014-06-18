require 'spec_helper'

describe EmbedController do

  let(:host) { "eviltrout.com" }
  let(:embed_url) { "http://eviltrout.com/2013/02/10/why-discourse-uses-emberjs.html" }

  it "is 404 without an embed_url" do
    get :comments
    response.should_not be_success
  end

  it "raises an error with a missing host" do
    SiteSetting.stubs(:embeddable_host).returns(nil)
    get :comments, embed_url: embed_url
    response.should_not be_success
  end

  context "with a host" do
    before do
      SiteSetting.stubs(:embeddable_host).returns(host)
    end

    it "raises an error with no referer" do
      get :comments, embed_url: embed_url
      response.should_not be_success
    end

    context "success" do

      before do
        controller.request.stubs(:referer).returns(embed_url)
      end

      after do
        response.should be_success
        response.headers['X-Frame-Options'].should == "ALLOWALL"
      end

      it "tells the topic retriever to work when no previous embed is found" do
        TopicEmbed.expects(:topic_id_for_embed).returns(nil)
        retriever = mock
        TopicRetriever.expects(:new).returns(retriever)
        retriever.expects(:retrieve)
        get :comments, embed_url: embed_url
      end

      it "creates a topic view when a topic_id is found" do
        TopicEmbed.expects(:topic_id_for_embed).returns(123)
        TopicView.expects(:new).with(123, nil, {limit: 100, exclude_first: true, exclude_deleted_users: true})
        get :comments, embed_url: embed_url
      end
    end

  end


end
