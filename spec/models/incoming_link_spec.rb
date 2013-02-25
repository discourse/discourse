require 'spec_helper'

describe IncomingLink do

  it { should belong_to :topic }
  it { should validate_presence_of :url }

  it { should ensure_length_of(:referer).is_at_least(3).is_at_most(1000) }
  it { should ensure_length_of(:domain).is_at_least(1).is_at_most(100) }

  describe 'local topic link' do

    it 'should validate properly' do
      Fabricate.build(:incoming_link).should be_valid
    end

    describe 'saving local link' do

      before do
        @post = Fabricate(:post)
        @topic = @post.topic
        @incoming_link = IncomingLink.create(url: "/t/slug/#{@topic.id}/#{@post.post_number}",
                                             referer: "http://twitter.com")
      end

      describe 'incoming link counts' do
        it "increases the post's incoming link count" do
          lambda { @incoming_link.save; @post.reload }.should change(@post, :incoming_link_count).by(1)
        end

        it "increases the topic's incoming link count" do
          lambda { @incoming_link.save; @topic.reload }.should change(@topic, :incoming_link_count).by(1)
        end

      end

      describe 'after save' do
        before do
          @incoming_link.save
        end

        it 'has a domain' do
          @incoming_link.domain.should == "twitter.com"
        end

        it 'has the topic_id' do
          @incoming_link.topic_id.should == @topic.id
        end

        it 'has the post_number' do
          @incoming_link.post_number.should == @post.post_number
        end
      end

    end
  end

  describe 'non-topic url' do

    before do
      @link = Fabricate(:incoming_link_not_topic)
    end

    it 'has no topic_id' do
      @link.topic_id.should be_blank
    end

    it 'has no post_number' do
      @link.topic_id.should be_blank
    end

  end


end
