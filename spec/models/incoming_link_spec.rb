require 'spec_helper'

describe IncomingLink do

  it { should belong_to :topic }
  it { should validate_presence_of :url }

  let(:post) { Fabricate(:post) }

  let(:topic) { post.topic }

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

    it "does not explode with bad referer" do
      IncomingLink.add(req('http://sam.com','file:///Applications/Install/75067ABC-C9D1-47B7-8ACE-76AEDE3911B2/Install/'))
    end

    it "does not explode with bad referer 2" do
      IncomingLink.add(req('http://sam.com','http://disqus.com/embed/comments/?disqus_version=42750f96&base=default&f=sergeiklimov&t_i=871%20http%3A%2F%2Fsergeiklimov.biz%2F%3Fp%3D871&t_u=http%3A%2F%2Fsergeiklimov.biz%2F2014%2F02%2Fweb%2F&t_e=%D0%91%D0%BB%D0%BE%D0%B3%20%2F%20%D1%84%D0%BE%D1%80%D1%83%D0%BC%20%2F%20%D1%81%D0%B0%D0%B9%D1%82%20%D0%B4%D0%BB%D1%8F%20Gremlins%2C%20Inc.%20%26%238212%3B%20%D0%B8%D1%89%D0%B5%D0%BC%20%D1%81%D0%BF%D0%B5%D1%86%D0%B8%D0%B0%D0%BB%D0%B8%D1%81%D1%82%D0%B0%20(UPD%3A%20%D0%9D%D0%90%D0%A8%D0%9B%D0%98!!)&t_d=%D0%91%D0%BB%D0%BE%D0%B3%20%2F%20%D1%84%D0%BE%D1%80%D1%83%D0%BC%20%2F%20%D1%81%D0%B0%D0%B9%D1%82%20%D0%B4%D0%BB%D1%8F%20Gremlins%2C%20Inc.%20%E2%80%94%20%D0%B8%D1%89%D0%B5%D0%BC%20%D1%81%D0%BF%D0%B5%D1%86%D0%B8%D0%B0%D0%BB%D0%B8%D1%81%D1%82%D0%B0%20(UPD%3A%20%D0%9D%D0%90%D0%A8%D0%9B%D0%98!!)&t_t=%D0%91%D0%BB%D0%BE%D0%B3%20%2F%20%D1%84%D0%BE%D1%80%D1%83%D0%BC%20%2F%20%D1%81%D0%B0%D0%B9%D1%82%20%D0%B4%D0%BB%D1%8F%20Gremlins%2C%20Inc.%20%26%238212%3B%20%D0%B8%D1%89%D0%B5%D0%BC%20%D1%81%D0%BF%D0%B5%D1%86%D0%B8%D0%B0%D0%BB%D0%B8%D1%81%D1%82%D0%B0%20(UPD%3A%20%D0%9D%D0%90%D0%A8%D0%9B%D0%98!!)&s_o=default&l='))
    end

    it "does nothing if referer is empty" do
      IncomingLink.expects(:create).never
      IncomingLink.add(req('http://somesite.com'))
    end

    it "does nothing if referer is same as host" do
      IncomingLink.expects(:create).never
      IncomingLink.add(req('http://somesite.com', 'http://somesite.com'))
    end

    it "tracks visits for invalid referers" do
      IncomingLink.add(req('http://somesite.com', 'bang bang bang'))
      # no current user, don't track
      IncomingLink.count.should == 0
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
      link = Fabricate.build(:incoming_link_not_topic)
      link.topic_id.should be_blank
      link.user_id.should be_blank
    end

  end

end
