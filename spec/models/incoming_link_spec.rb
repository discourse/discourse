require 'spec_helper'

describe IncomingLink do

  it { should belong_to :topic }
  it { should validate_presence_of :url }

  it { should ensure_length_of(:referer).is_at_least(3).is_at_most(1000) }
  it { should ensure_length_of(:domain).is_at_least(1).is_at_most(100) }

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
    it "does nothing if referer is empty" do
      env = Rack::MockRequest.env_for("http://somesite.com")
      request = Rack::Request.new(env)
      IncomingLink.expects(:create).never
      IncomingLink.add(request)
    end

    it "does nothing if referer is same as host" do
      env = Rack::MockRequest.env_for("http://somesite.com")
      env['HTTP_REFERER'] = 'http://somesite.com'
      request = Rack::Request.new(env)
      IncomingLink.expects(:create).never
      IncomingLink.add(request)
    end

    it "expects to be called with referer and user id" do
      env = Rack::MockRequest.env_for("http://somesite.com")
      env['HTTP_REFERER'] = 'http://some.other.site.com'
      request = Rack::Request.new(env)
      IncomingLink.expects(:create).once.returns(true)
      IncomingLink.add(request, 100)
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
