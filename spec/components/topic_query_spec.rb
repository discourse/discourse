require 'spec_helper'
require 'topic_view'

describe TopicQuery do

  let!(:user) { Fabricate(:coding_horror) }
  let(:creator) { Fabricate(:user) }
  let(:topic_query) { TopicQuery.new(user) }

  let(:moderator) { Fabricate(:moderator) }
  let(:admin) { Fabricate(:moderator) }

  context 'a bunch of topics' do
    let!(:regular_topic) { Fabricate(:topic, title: 'regular', user: creator, bumped_at: 15.minutes.ago) }
    let!(:pinned_topic) { Fabricate(:topic, title: 'pinned', user: creator, pinned: true, bumped_at: 10.minutes.ago) }
    let!(:archived_topic) { Fabricate(:topic, title: 'archived', user: creator, archived: true, bumped_at: 6.minutes.ago) }
    let!(:invisible_topic) { Fabricate(:topic, title: 'invisible', user: creator, visible: false, bumped_at: 5.minutes.ago) }
    let!(:closed_topic) { Fabricate(:topic, title: 'closed', user: creator, closed: true, bumped_at: 1.minute.ago) }

    context 'list_popular' do
      let(:topics) { topic_query.list_popular.topics }

      it "returns the topics in the correct order" do
        topics.should == [pinned_topic, closed_topic, archived_topic, regular_topic]
      end

      it "includes the invisible topic if you're a moderator" do
        TopicQuery.new(moderator).list_popular.topics.include?(invisible_topic).should be_true
      end

      it "includes the invisible topic if you're an admin" do
        TopicQuery.new(admin).list_popular.topics.include?(invisible_topic).should be_true
      end
    end

  end

  context 'categorized' do
    let(:category) { Fabricate(:category) }    
    let!(:topic_no_cat) { Fabricate(:topic) }    
    let!(:topic_in_cat) { Fabricate(:topic, category: category) }
    
    it "returns the topic without a category when filtering uncategorized" do
      topic_query.list_uncategorized.topics.should == [topic_no_cat]
    end

    it "returns the topic with a category when filtering by category" do
      topic_query.list_category(category).topics.should == [topic_in_cat]
    end

    it "returns nothing when filtering by another category" do
      topic_query.list_category(Fabricate(:category, name: 'new cat')).topics.should be_blank
    end
  end

  context 'unread / read topics' do

    context 'with no data' do

      it "has no read topics" do
        topic_query.list_unread.topics.should be_blank
      end

      it "has no unread topics" do
        topic_query.list_unread.topics.should be_blank
      end

      it "has an unread count of 0" do
        topic_query.unread_count.should == 0
      end
    end

    context 'with read data' do
      let!(:partially_read) { Fabricate(:post, user: creator).topic }
      let!(:fully_read) { Fabricate(:post, user: creator).topic }

      before do
        TopicUser.update_last_read(user, partially_read.id, 0, 0)
        TopicUser.update_last_read(user, fully_read.id, 1, 0)
      end

      context 'list_unread' do
        it 'contains no topics' do
          topic_query.list_unread.topics.should == []
        end

        it "returns 0 as the unread count" do
          topic_query.unread_count.should == 0
        end
      end

      context 'user with auto_track_topics list_unread' do 
        before do 
          user.auto_track_topics_after_msecs = 0
          user.save
        end
        
        it 'only contains the partially read topic' do
          topic_query.list_unread.topics.should == [partially_read]
        end

        it "returns 1 as the unread count" do
          topic_query.unread_count.should == 1
        end
      end

      context 'list_read' do
        it 'contain both topics ' do
          topic_query.list_read.topics.should =~ [fully_read, partially_read]
        end      
      end
    end

  end

  context 'list_favorited' do

    let(:topic) { Fabricate(:topic) }

    it "returns no results when the user hasn't favorited anything" do
      topic_query.list_favorited.topics.should be_blank
    end

    context 'with a favorited topic' do
      
      before do
        topic.toggle_star(user, true)
      end

      it "returns the topic after it has been favorited" do
        topic_query.list_favorited.topics.should == [topic]
      end
    end

  end

  context 'list_new' do

    context 'without a new topic' do
      it "has an new_count of 0" do
        topic_query.new_count.should == 0
      end

      it "has no new topics" do
        topic_query.list_new.topics.should be_blank
      end
    end

    context 'with a new topic' do
      let!(:new_topic) { Fabricate(:topic, user: creator, bumped_at: 10.minutes.ago) }      
      let(:topics) { topic_query.list_new.topics }


      it "contains the new topic" do
        topics.should == [new_topic]
      end

      context "muted topics" do
        before do
          new_topic.notify_muted!(user)
        end

        it "returns an empty set" do          
          topics.should be_blank
        end

        context 'un-muted' do
          before do
            new_topic.notify_tracking!(user)
          end

          it "returns the topic again" do
            topics.should == [new_topic]
          end
        end
      end        
    end
   
  end

  context 'list_posted' do
    let(:topics) { topic_query.list_posted.topics }

    it "returns blank when there are no posted topics" do
      topics.should be_blank
    end

    context 'created topics' do
      let!(:created_topic) { Fabricate(:post, user: user).topic }

      it "includes the created topic" do
        topics.include?(created_topic).should be_true
      end
    end

    context "topic you've posted in" do
      let(:other_users_topic) { Fabricate(:post, user: creator).topic }
      let!(:your_post) { Fabricate(:post, user: user, topic: other_users_topic )}

      it "includes the posted topic" do
        topics.include?(other_users_topic).should be_true
      end

    end
  end

  context 'suggested_for' do

    context 'when anonymous' do
      let(:topic) { Fabricate(:topic) }
      let!(:new_topic) { Fabricate(:post, user: creator).topic }

      it "should return the new topic" do
        TopicQuery.new.list_suggested_for(topic).topics.should == [new_topic]  
      end

    end

    context 'when logged in' do

      let(:topic) { Fabricate(:topic) }
      let(:suggested_topics) { topic_query.list_suggested_for(topic).topics.map{|t| t.id} }

      it "should return empty results when there is nothing to find" do
        suggested_topics.should be_blank
      end

      context 'with some existing topics' do
        let!(:partially_read) { Fabricate(:post, user: creator).topic }
        let!(:new_topic) { Fabricate(:post, user: creator).topic }
        let!(:fully_read) { Fabricate(:post, user: creator).topic }     

        before do
          user.auto_track_topics_after_msecs = 0
          user.save
          TopicUser.update_last_read(user, partially_read.id, 0, 0)
          TopicUser.update_last_read(user, fully_read.id, 1, 0)
        end

        it "won't return new or fully read if there are enough partially read topics" do
          SiteSetting.stubs(:suggested_topics).returns(1)
          suggested_topics.should == [partially_read.id]
        end

        it "won't fully read if there are enough partially read topics and new topics" do
          SiteSetting.stubs(:suggested_topics).returns(2)
          suggested_topics.should == [partially_read.id, new_topic.id]
        end

        it "returns unread, then new, then random" do
          SiteSetting.stubs(:suggested_topics).returns(3)
          suggested_topics.should == [partially_read.id, new_topic.id, fully_read.id]
        end

      end        
    end

  end

end
