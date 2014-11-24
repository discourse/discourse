require 'spec_helper'

describe IncomingLinksReport do

  describe 'integration' do
    it 'runs correctly' do
      p1 = create_post
      p2 = create_post

      p1.topic.save
      p2.topic.save

      7.times do |n|
        IncomingLink.add(
          referer: 'http://test.com',
          host: 'http://discourse.example.com',
          topic_id: p1.topic.id,
          ip_address: "10.0.0.#{n}",
          username: p1.user.username
        )
      end
      3.times do |n|
        IncomingLink.add(
          referer: 'http://foo.com',
          host: 'http://discourse.example.com',
          topic_id: p2.topic.id,
          ip_address: "10.0.0.#{n + 7}",
          username: p2.user.username
        )
      end
      2.times do |n|
        IncomingLink.add(
          referer: 'http://foo.com',
          host: 'http://discourse.example.com',
          topic_id: p2.topic.id,
          ip_address: "10.0.0.#{n + 7 + 3}",
          username: p1.user.username # ! user1 is the referer !
        )
      end

      r = IncomingLinksReport.find('top_referrers').as_json
      r[:data].should == [
        {username: p1.user.username, num_clicks: 7 + 2, num_topics: 2},
        {username: p2.user.username, num_clicks: 3, num_topics: 1}
      ]

      r = IncomingLinksReport.find('top_traffic_sources').as_json
      r[:data].should == [
        {domain: 'test.com', num_clicks: 7, num_topics: 1},
        {domain: 'foo.com', num_clicks: 3 + 2, num_topics: 1}
      ]

      r = IncomingLinksReport.find('top_referred_topics').as_json
      r[:data].should == [
        {topic_id: p1.topic.id, topic_title: p1.topic.title, topic_slug: p1.topic.slug, num_clicks: 7},
        {topic_id: p2.topic.id, topic_title: p2.topic.title, topic_slug: p2.topic.slug, num_clicks: 2 + 3},
      ]
    end
  end

  describe 'top_referrers' do
    subject(:top_referrers) { IncomingLinksReport.find('top_referrers').as_json }

    let(:amy) { Fabricate(:user, username: 'amy') }
    let(:bob) { Fabricate(:user, username: 'bob') }
    let(:post1) { Fabricate(:post) }
    let(:post2) { Fabricate(:post) }
    let(:topic1) { post1.topic }
    let(:topic2) { post2.topic }

    def save_base_objects
      amy.save; bob.save
      post1.save; post2.save
      topic1.save; topic2.save
    end

    it 'returns localized titles' do
      top_referrers[:title].should be_present
      top_referrers[:xaxis].should be_present
      top_referrers[:ytitles].should be_present
      top_referrers[:ytitles][:num_clicks].should be_present
      top_referrers[:ytitles][:num_topics].should be_present
    end

    it 'with no IncomingLink records, it returns correct data' do
      IncomingLink.delete_all
      top_referrers[:data].size.should == 0
    end

    it 'with some IncomingLink records, it returns correct data' do
      save_base_objects

      2.times do
        Fabricate(:incoming_link, user: amy, post: post1).save
      end
      Fabricate(:incoming_link, user: amy, post: post2).save
      2.times do
        Fabricate(:incoming_link, user: bob, post: post1).save
      end

      top_referrers[:data][0].should == {username: 'amy', num_clicks: 3, num_topics: 2}
      top_referrers[:data][1].should == {username: 'bob', num_clicks: 2, num_topics: 1}
    end
  end

  describe 'top_traffic_sources' do
    subject(:top_traffic_sources) { IncomingLinksReport.find('top_traffic_sources').as_json }

    # TODO: STOP THE STUBBING
    def stub_empty_traffic_source_data
      IncomingLinksReport.stubs(:link_count_per_domain).returns({})
      IncomingLinksReport.stubs(:topic_count_per_domain).returns({})
      IncomingLinksReport.stubs(:user_count_per_domain).returns({})
    end

    it 'returns localized titles' do
      stub_empty_traffic_source_data
      top_traffic_sources[:title].should be_present
      top_traffic_sources[:xaxis].should be_present
      top_traffic_sources[:ytitles].should be_present
      top_traffic_sources[:ytitles][:num_clicks].should be_present
      top_traffic_sources[:ytitles][:num_topics].should be_present
      top_traffic_sources[:ytitles][:num_users].should be_present
    end

    it 'with no IncomingLink records, it returns correct data' do
      stub_empty_traffic_source_data
      top_traffic_sources[:data].size.should == 0
    end

    it 'with some IncomingLink records, it returns correct data' do
      IncomingLinksReport.stubs(:link_count_per_domain).returns({'twitter.com' => 8, 'facebook.com' => 3})
      IncomingLinksReport.stubs(:topic_count_per_domain).returns({'twitter.com' => 2, 'facebook.com' => 3})
      top_traffic_sources[:data][0].should == {domain: 'twitter.com', num_clicks: 8, num_topics: 2}
      top_traffic_sources[:data][1].should == {domain: 'facebook.com', num_clicks: 3, num_topics: 3}
    end
  end

  describe 'top_referred_topics' do
    subject(:top_referred_topics) { IncomingLinksReport.find('top_referred_topics').as_json }

    # TODO: STOP THE STUBBING
    def stub_empty_referred_topics_data
      IncomingLinksReport.stubs(:link_count_per_topic).returns({})
    end

    it 'returns localized titles' do
      stub_empty_referred_topics_data
      top_referred_topics[:title].should be_present
      top_referred_topics[:xaxis].should be_present
      top_referred_topics[:ytitles].should be_present
      top_referred_topics[:ytitles][:num_clicks].should be_present
    end

    it 'with no IncomingLink records, it returns correct data' do
      stub_empty_referred_topics_data
      top_referred_topics[:data].size.should == 0
    end

    it 'with some IncomingLink records, it returns correct data' do
      topic1 = Fabricate.build(:topic, id: 123); topic2 = Fabricate.build(:topic, id: 234)
      # TODO: OMG OMG THE STUBBING
      IncomingLinksReport.stubs(:link_count_per_topic).returns({topic1.id => 8, topic2.id => 3})
      Topic.stubs(:select).returns(Topic); Topic.stubs(:where).returns(Topic) # bypass some activerecord methods
      Topic.stubs(:all).returns([topic1, topic2])
      top_referred_topics[:data][0].should == {topic_id: topic1.id, topic_title: topic1.title, topic_slug: topic1.slug, num_clicks: 8 }
      top_referred_topics[:data][1].should == {topic_id: topic2.id, topic_title: topic2.title, topic_slug: topic2.slug, num_clicks: 3 }
    end
  end

end
