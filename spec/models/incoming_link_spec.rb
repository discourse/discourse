require 'spec_helper'

describe IncomingLink do

  it { should belong_to :topic }
  it { should validate_presence_of :url }

  let :post do
    Fabricate(:post)
  end

  let :topic do
    post.topic
  end

  let :incoming_link do
    IncomingLink.create(url: "/t/slug/#{topic.id}/#{post.post_number}",
                                             referer: "http://twitter.com")
  end

  describe 'local topic link' do

    it 'should validate properly' do
      Fabricate.build(:incoming_link).should be_valid
    end

    describe 'tracking link counts' do
      it "increases the incoming link counts" do
        incoming_link
        lambda { post.reload }.should change(post, :incoming_link_count).by(1)
        lambda { topic.reload }.should change(topic, :incoming_link_count).by(1)
      end
    end

    describe 'saving local link' do
      it 'has correct info set' do
        incoming_link.domain.should == "twitter.com"
        incoming_link.topic_id.should == topic.id
        incoming_link.post_number.should == post.post_number
      end

    end
  end

  describe 'add' do
    class TestRequest<Rack::Request
      attr_accessor :remote_ip
    end
    def req(url, referer=nil)
      env = Rack::MockRequest.env_for(url)
      env['HTTP_REFERER'] = referer if referer
      TestRequest.new(env)
    end

    it "does nothing if referer is empty" do
      IncomingLink.expects(:create).never
      IncomingLink.add(req('http://somesite.com'))
    end

    it "does nothing if referer is same as host" do
      IncomingLink.expects(:create).never
      IncomingLink.add(req('http://somesite.com', 'http://somesite.com'))
    end

    it "expects to be called with referer and user id" do
      IncomingLink.expects(:create).once.returns(true)
      IncomingLink.add(req('http://somesite.com', 'http://some.other.site.com'), build(:user))
    end

    it "is able to look up user_id and log it from the GET params" do
      user = Fabricate(:user, username: "Bob")
      IncomingLink.add(req('http://somesite.com?u=bob'))
      first = IncomingLink.first
      first.user_id.should == user.id
    end
  end

  describe 'non-topic url' do
    it 'has nothing set' do
      link = Fabricate(:incoming_link_not_topic)
      link.topic_id.should be_blank
      link.user_id.should be_blank
    end

  end

end
