require "spec_helper"

describe "Stores incoming links" do
  before do
    TopicUser.stubs(:track_visit!)
  end

  let :topic do
    Fabricate(:post).topic
  end

  it "doesn't store an incoming link when there's no referer" do
    lambda {
      get topic.relative_url
    }.should_not change(IncomingLink, :count)
  end

  it "doesn't raise an error on a very long link" do
    lambda { get topic.relative_url, nil, {'HTTP_REFERER' => "http://#{'a' * 2000}.com"} }.should_not raise_error
  end

  it "stores an incoming link when there is an off-site referer" do
    lambda {
      get topic.relative_url, nil, {'HTTP_REFERER' => "http://google.com/search"}
    }.should change(IncomingLink, :count).by(1)
  end

  describe 'after inserting an incoming link' do

    before do
      get topic.relative_url + "/1", nil, {'HTTP_REFERER' => "http://google.com/search"}
      @last_link = IncomingLink.last
      @last_link.topic_id.should == topic.id
      @last_link.post_number.should == 1
    end

  end

end
