# frozen_string_literal: true

require 'rails_helper'

describe IncomingLink do

  fab!(:sharing_user) { Fabricate(:user, name: 'Alice') }
  fab!(:current_user) { Fabricate(:user, name: 'Bob') }
  fab!(:post) { Fabricate(:post) }
  let(:topic) { post.topic }

  let :incoming_link do
    IncomingLink.add(host: "a.com", referer: "http://twitter.com", post_id: post.id, ip_address: '1.1.1.1')
  end

  describe 'local topic link' do

    describe 'tracking link counts' do
      it "increases the incoming link counts" do
        link = incoming_link

        expect(link.domain).to eq "twitter.com"
        expect(link.post_id).to eq post.id

        post.reload
        expect(post.incoming_link_count).to eq 1

        topic.reload
        expect(topic.incoming_link_count).to eq 1
      end
    end

  end

  describe 'add' do

    def req(opts)
      {
        referer: opts[:referer],
        host: opts[:host] || 'test.com',
        current_user: opts[:current_user],
        topic_id: opts[:topic_id],
        post_number: opts[:post_number],
        post_id: opts[:post_id],
        username: opts[:username],
        ip_address: opts[:ip_address]
      }
    end

    def add(opts)
      IncomingLink.add(req(opts))
    end

    it "does not explode with bad username" do
      add(
        username: "test\0test"
      )
    end

    it "does not explode with bad referer" do
      add(
        referer: 'file:///Applications/Install/75067ABC-C9D1-47B7-8ACE-76AEDE3911B2/Install/',
        post_id: 1
      )
    end

    it "does not explode with bad referer 2" do
      add(
        post_id: 1,
        referer: 'http://disqus.com/embed/comments/?disqus_version=42750f96&base=default&f=sergeiklimov&t_i=871%20http%3A%2F%2Fsergeiklimov.biz%2F%3Fp%3D871&t_u=http%3A%2F%2Fsergeiklimov.biz%2F2014%2F02%2Fweb%2F&t_e=%D0%91%D0%BB%D0%BE%D0%B3%20%2F%20%D1%84%D0%BE%D1%80%D1%83%D0%BC%20%2F%20%D1%81%D0%B0%D0%B9%D1%82%20%D0%B4%D0%BB%D1%8F%20Gremlins%2C%20Inc.%20%26%238212%3B%20%D0%B8%D1%89%D0%B5%D0%BC%20%D1%81%D0%BF%D0%B5%D1%86%D0%B8%D0%B0%D0%BB%D0%B8%D1%81%D1%82%D0%B0%20(UPD%3A%20%D0%9D%D0%90%D0%A8%D0%9B%D0%98!!)&t_d=%D0%91%D0%BB%D0%BE%D0%B3%20%2F%20%D1%84%D0%BE%D1%80%D1%83%D0%BC%20%2F%20%D1%81%D0%B0%D0%B9%D1%82%20%D0%B4%D0%BB%D1%8F%20Gremlins%2C%20Inc.%20%E2%80%94%20%D0%B8%D1%89%D0%B5%D0%BC%20%D1%81%D0%BF%D0%B5%D1%86%D0%B8%D0%B0%D0%BB%D0%B8%D1%81%D1%82%D0%B0%20(UPD%3A%20%D0%9D%D0%90%D0%A8%D0%9B%D0%98!!)&t_t=%D0%91%D0%BB%D0%BE%D0%B3%20%2F%20%D1%84%D0%BE%D1%80%D1%83%D0%BC%20%2F%20%D1%81%D0%B0%D0%B9%D1%82%20%D0%B4%D0%BB%D1%8F%20Gremlins%2C%20Inc.%20%26%238212%3B%20%D0%B8%D1%89%D0%B5%D0%BC%20%D1%81%D0%BF%D0%B5%D1%86%D0%B8%D0%B0%D0%BB%D0%B8%D1%81%D1%82%D0%B0%20(UPD%3A%20%D0%9D%D0%90%D0%A8%D0%9B%D0%98!!)&s_o=default&l='
      )
    end

    it "does nothing if referer is empty" do
      add(post_id: 1)
      expect(IncomingLink.count).to eq 0
    end

    it "does nothing if referer is same as host" do
      add(post_id: 1, host: 'example.com', referer: 'http://example.com')
      expect(IncomingLink.count).to eq 0
    end

    it "tracks not visits for invalid referers" do
      add(post_id: 1, referer: 'bang bang bang')
      expect(IncomingLink.count).to eq 0
    end

    it "expects to be called with referer and user id" do
      add(host: "test.com", referer: 'http://some.other.site.com', post_id: 1)
      expect(IncomingLink.count).to eq 1
    end

    it "is able to look up user_id and log it from the GET params" do
      add(host: 'test.com', username: sharing_user.username, post_id: 1)

      first = IncomingLink.first
      expect(first.user_id).to eq sharing_user.id
    end

    it "logs an incoming and stores IP with no current user" do
      add(referer: 'https://example.social/@alice/1234',
          post_id: post.id,
          username: sharing_user.username,
          current_user: nil,
          ip_address: '100.64.1.1')
      expect(IncomingLink.count).to eq 1
      il = IncomingLink.last
      expect(il.ip_address).to eq '100.64.1.1'
    end

    it "does not log when the sharing user clicks their own link" do
      add(referer: 'https://example.social/@alice/1234',
          post_id: post.id,
          username: sharing_user.username,
          current_user: sharing_user,
          ip_address: '100.64.1.2')
      expect(IncomingLink.count).to eq 0
    end

    it "does not store ip address when a logged-in user clicks" do
      add(referer: 'https://example.social/@alice/1234',
          post_id: post.id,
          username: sharing_user.username,
          current_user: current_user,
          ip_address: '100.64.1.3')
      expect(IncomingLink.count).to eq 1
      il = IncomingLink.last
      expect(il.ip_address).to eq nil
      expect(il.current_user_id).to eq current_user.id
    end
  end

end
