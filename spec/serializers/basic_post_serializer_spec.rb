require 'rails_helper'
require_dependency 'post'
require_dependency 'user'

describe BasicPostSerializer do

  context "name" do
    let(:user) { Fabricate.build(:user) }
    let(:post) { Fabricate.build(:post, user: user) }
    let(:serializer) { BasicPostSerializer.new(post, scope: Guardian.new, root: false) }
    let(:json) { serializer.as_json }

    it "returns the name it when `enable_names` is true" do
      SiteSetting.enable_names = true
      expect(json[:name]).to be_present
    end

    it "doesn't return the name it when `enable_names` is false" do
      SiteSetting.enable_names = false
      expect(json[:name]).to be_blank
    end

  end

  context "ignored" do
    let(:user) { Fabricate(:user, trust_level: 2) }
    let(:another_user) { Fabricate(:user) }
    let!(:ignored_user) { Fabricate(:ignored_user, user: user, ignored_user: another_user) }
    let(:topic) { Fabricate(:topic) }
    let(:post) { Fabricate(:post, user: user, topic: topic) }
    let(:serializer) { BasicPostSerializer.new(post, scope: Guardian.new(user), root: false) }
    let(:json) { serializer.as_json }

    context "when ignore_user_enable is OFF" do
      it "ignored is false" do
        expect(json[:ignored]).to eq(false)
      end
    end

    context "when ignore_user_enable is ON" do
      before do
        SiteSetting.ignore_user_enabled = true
      end

      context "when post is first in topic" do
        let(:post) { Fabricate.build(:post, user: another_user, topic: topic) }

        it "ignored is true" do
          expect(json[:ignored]).to eq(true)
        end
      end

      context "when post by an ignored user is a reply to another post in topic" do
        let(:post) { Fabricate(:post, user: user, topic: topic) }
        let(:reply) { Fabricate(:post, topic: topic, user: another_user, reply_to_post_number: post.post_number) }
        let(:serializer) { BasicPostSerializer.new(reply, scope: Guardian.new(user), root: false) }

        it "ignored is true" do
          expect(json[:ignored]).to eq(true)
        end
      end
    end

  end

end
