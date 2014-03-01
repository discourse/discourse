require 'spec_helper'
require_dependency 'topic_retriever'

describe TopicRetriever do

  let(:embed_url) { "http://eviltrout.com/2013/02/10/why-discourse-uses-emberjs.html" }
  let(:topic_retriever) { TopicRetriever.new(embed_url) }

  it "does not call perform_retrieve when embeddable_host is not set" do
    SiteSetting.stubs(:embeddable_host).returns(nil)
    topic_retriever.expects(:perform_retrieve).never
    topic_retriever.retrieve
  end

  it "does not call perform_retrieve when embeddable_host is different than the host of the URL" do
    SiteSetting.stubs(:embeddable_host).returns("eviltuna.com")
    topic_retriever.expects(:perform_retrieve).never
    topic_retriever.retrieve
  end

  it "does not call perform_retrieve when the embed url is not a url" do
    r = TopicRetriever.new("not a url")
    r.expects(:perform_retrieve).never
    r.retrieve
  end

  context "with a valid host" do
    before do
      SiteSetting.stubs(:embeddable_host).returns("eviltrout.com")
    end

    it "calls perform_retrieve if it hasn't been retrieved recently" do
      topic_retriever.expects(:perform_retrieve).once
      topic_retriever.expects(:retrieved_recently?).returns(false)
      topic_retriever.retrieve
    end

    it "doesn't call perform_retrieve if it's been retrieved recently" do
      topic_retriever.expects(:perform_retrieve).never
      topic_retriever.expects(:retrieved_recently?).returns(true)
      topic_retriever.retrieve
    end

  end

end
