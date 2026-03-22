# frozen_string_literal: true

RSpec.describe PostSerializer do
  fab!(:user)
  fab!(:post_author, :user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:target_post, :post) { Fabricate(:post, topic: topic, user: post_author) }

  let(:guardian) { Guardian.new(user) }
  let(:topic_view) { TopicView.new(topic, user) }

  let(:serialized) do
    post = topic_view.posts.find { |p| p.id == target_post.id }
    serializer = described_class.new(post, scope: guardian, root: false)
    serializer.topic_view = topic_view
    serializer.as_json
  end

  before { SiteSetting.discourse_boosts_enabled = true }

  describe "boosts" do
    fab!(:boost) { Fabricate(:boost, post: target_post, user: user) }

    it "includes serialized boosts" do
      boosts = serialized[:boosts]

      expect(boosts.length).to eq(1)
      expect(boosts.first).to include(id: boost.id, cooked: boost.cooked)
      expect(boosts.first[:user][:id]).to eq(user.id)
    end

    context "when plugin is disabled" do
      before { SiteSetting.discourse_boosts_enabled = false }

      it "excludes boosts" do
        expect(serialized).not_to have_key(:boosts)
      end
    end

    context "when boost author is ignored by the viewing user" do
      fab!(:ignored_user, :user)
      fab!(:ignored_boost) { Fabricate(:boost, post: target_post, user: ignored_user) }

      before { Fabricate(:ignored_user, user: user, ignored_user: ignored_user) }

      it "excludes boosts from ignored users" do
        boosts = serialized[:boosts]
        expect(boosts.map { |b| b[:user][:id] }).not_to include(ignored_user.id)
      end

      context "when ignored user is a staff member" do
        before { ignored_user.update!(admin: true) }

        it "still includes boosts from ignored staff" do
          boosts = serialized[:boosts]
          expect(boosts.map { |b| b[:user][:id] }).to include(ignored_user.id)
        end
      end
    end

    context "when boosts association is not loaded" do
      let(:serialized) do
        post = Post.find(target_post.id)
        serializer = described_class.new(post, scope: guardian, root: false)
        serializer.as_json
      end

      it "excludes boosts" do
        expect(serialized).not_to have_key(:boosts)
      end
    end
  end

  describe "can_boost" do
    it "is true for a regular user on another user's post" do
      expect(serialized[:can_boost]).to eq(true)
    end

    context "when user is silenced" do
      before { user.update!(silenced_till: 1.year.from_now) }

      it "is false" do
        expect(serialized[:can_boost]).to eq(false)
      end
    end

    context "when viewing own post" do
      let(:guardian) { Guardian.new(post_author) }
      let(:topic_view) { TopicView.new(topic, post_author) }

      it "is false" do
        expect(serialized[:can_boost]).to eq(false)
      end
    end

    context "when user has already boosted the post" do
      before { Fabricate(:boost, post: target_post, user: user) }

      it "is false" do
        expect(serialized[:can_boost]).to eq(false)
      end
    end

    context "when post has reached the boost limit" do
      before do
        SiteSetting.discourse_boosts_max_per_post = 1
        Fabricate(:boost, post: target_post)
      end

      it "is false" do
        expect(serialized[:can_boost]).to eq(false)
      end
    end

    context "when user is anonymous" do
      let(:guardian) { Guardian.new }
      let(:topic_view) { TopicView.new(topic) }

      it "is false" do
        expect(serialized[:can_boost]).to eq(false)
      end
    end
  end
end
