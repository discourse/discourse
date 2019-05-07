# frozen_string_literal: true

require 'rails_helper'

describe IncomingLinksReport do

  before do
    freeze_time DateTime.parse('2010-01-01 6:00')
  end

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
      expect(r[:data]).to eq [
        {
          user_avatar_template: User.default_template(p1.user.username),
          username: p1.user.username,
          user_id: p1.user.id,
          num_clicks: 7 + 2, num_topics: 2
        },
        {
          user_avatar_template: User.default_template(p2.user.username),
          username: p2.user.username,
          user_id: p2.user.id,
          num_clicks: 3,
          num_topics: 1
        }
      ]

      r = IncomingLinksReport.find('top_traffic_sources').as_json
      expect(r[:data]).to eq [
        { domain: 'test.com', num_clicks: 7, num_topics: 1 },
        { domain: 'foo.com', num_clicks: 3 + 2, num_topics: 1 }
      ]

      r = IncomingLinksReport.find('top_referred_topics').as_json
      expect(r[:data]).to eq [
        { topic_id: p1.topic.id, topic_title: p1.topic.title, topic_url: p1.topic.relative_url, num_clicks: 7 },
        { topic_id: p2.topic.id, topic_title: p2.topic.title, topic_url: p2.topic.relative_url, num_clicks: 2 + 3 },
      ]
    end

    it "does not report PMs" do
      public_topic = Fabricate(:topic)
      message_topic = Fabricate(:private_message_topic)

      public_post = Fabricate(:post, topic: public_topic)
      message_post = Fabricate(:post, topic: message_topic)

      IncomingLink.add(
        referer: "http://foo.com",
        host: "http://discourse.example.com",
        topic_id: public_topic.id,
        id_address: "1.2.3.4",
        username: public_post.user.username,
      )

      IncomingLink.add(
        referer: "http://foo.com",
        host: "http://discourse.example.com",
        topic_id: message_topic.id,
        id_address: "5.6.7.8",
        username: message_post.user.username,
      )

      r = IncomingLinksReport.find('top_referrers').as_json
      expect(r[:data]).to eq [
        {
          user_avatar_template: User.default_template(public_post.user.username),
          username: public_post.user.username,
          user_id: public_post.user.id,
          num_clicks: 1,
          num_topics: 1
        }
      ]

      r = IncomingLinksReport.find('top_traffic_sources').as_json
      expect(r[:data]).to eq [
        { domain: 'foo.com', num_clicks: 1, num_topics: 1 },
      ]

      r = IncomingLinksReport.find('top_referred_topics').as_json
      expect(r[:data]).to eq [
        { topic_id: public_topic.id, topic_title: public_topic.title, topic_url: public_topic.relative_url, num_clicks: 1 },
      ]
    end
  end

  describe 'top_referrers' do
    subject(:top_referrers) { IncomingLinksReport.find('top_referrers').as_json }

    fab!(:amy) { Fabricate(:user, username: 'amy') }
    fab!(:bob) { Fabricate(:user, username: 'bob') }
    fab!(:post1) { Fabricate(:post) }
    fab!(:post2) { Fabricate(:post) }
    let(:topic1) { post1.topic }
    let(:topic2) { post2.topic }

    def save_base_objects
      amy.save; bob.save
      post1.save; post2.save
      topic1.save; topic2.save
    end

    it 'returns localized titles' do
      expect(top_referrers[:title]).to be_present
      expect(top_referrers[:xaxis]).to be_present
      expect(top_referrers[:ytitles]).to be_present
      expect(top_referrers[:ytitles][:num_clicks]).to be_present
      expect(top_referrers[:ytitles][:num_topics]).to be_present
    end

    it 'with no IncomingLink records, it returns correct data' do
      IncomingLink.delete_all
      expect(top_referrers[:data].size).to eq 0
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

      expect(top_referrers[:data][0]).to eq(
        user_avatar_template: User.default_template('amy'),
        username: 'amy',
        user_id: amy.id,
        num_clicks: 3,
        num_topics: 2
      )

      expect(top_referrers[:data][1]).to eq(
        user_avatar_template: User.default_template('bob'),
        username: 'bob',
        user_id: bob.id,
        num_clicks: 2,
        num_topics: 1
      )
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
      expect(top_traffic_sources[:title]).to be_present
      expect(top_traffic_sources[:xaxis]).to be_present
      expect(top_traffic_sources[:ytitles]).to be_present
      expect(top_traffic_sources[:ytitles][:num_clicks]).to be_present
      expect(top_traffic_sources[:ytitles][:num_topics]).to be_present
      expect(top_traffic_sources[:ytitles][:num_users]).to be_present
    end

    it 'with no IncomingLink records, it returns correct data' do
      stub_empty_traffic_source_data
      expect(top_traffic_sources[:data].size).to eq 0
    end

    it 'with some IncomingLink records, it returns correct data' do
      IncomingLinksReport.stubs(:link_count_per_domain).returns('twitter.com' => 8, 'facebook.com' => 3)
      IncomingLinksReport.stubs(:topic_count_per_domain).returns('twitter.com' => 2, 'facebook.com' => 3)
      expect(top_traffic_sources[:data][0]).to eq(domain: 'twitter.com', num_clicks: 8, num_topics: 2)
      expect(top_traffic_sources[:data][1]).to eq(domain: 'facebook.com', num_clicks: 3, num_topics: 3)
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
      expect(top_referred_topics[:title]).to be_present
      expect(top_referred_topics[:xaxis]).to be_present
      expect(top_referred_topics[:ytitles]).to be_present
      expect(top_referred_topics[:ytitles][:num_clicks]).to be_present
    end

    it 'with no IncomingLink records, it returns correct data' do
      stub_empty_referred_topics_data
      expect(top_referred_topics[:data].size).to eq 0
    end

    it 'with some IncomingLink records, it returns correct data' do
      topic1 = Fabricate.build(:topic, id: 123); topic2 = Fabricate.build(:topic, id: 234)
      # TODO: OMG OMG THE STUBBING
      IncomingLinksReport.stubs(:link_count_per_topic).returns(topic1.id => 8, topic2.id => 3)
      # bypass some activerecord methods
      Topic.stubs(:select).returns(Topic)
      Topic.stubs(:where).returns(Topic)
      Topic.stubs(:all).returns([topic1, topic2])
      expect(top_referred_topics[:data][0]).to eq(topic_id: topic1.id, topic_title: topic1.title, topic_url: topic1.relative_url, num_clicks: 8)
      expect(top_referred_topics[:data][1]).to eq(topic_id: topic2.id, topic_title: topic2.title, topic_url: topic2.relative_url, num_clicks: 3)
    end
  end

end
