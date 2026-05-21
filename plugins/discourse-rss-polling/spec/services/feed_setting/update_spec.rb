# frozen_string_literal: true

RSpec.describe DiscourseRssPolling::FeedSetting::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:feed_url) }
    it { is_expected.to validate_presence_of(:author_username) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:category)
    fab!(:tag_1, :tag)
    fab!(:tag_2, :tag)

    let(:params) do
      {
        id: nil,
        feed_url: "https://blog.example.com/feed",
        author_username: user.username,
        discourse_category_id: category.id,
        discourse_tags: [tag_1.name, tag_2.name],
        feed_category_filter: "news",
      }
    end
    let(:dependencies) { {} }

    context "when the contract is invalid" do
      before { params[:feed_url] = nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the author does not exist" do
      before { params[:author_username] = "ghost" }

      it { is_expected.to fail_to_find_a_model(:user) }
    end

    context "when everything is ok" do
      context "when creating a new feed" do
        it { is_expected.to run_successfully }

        it "creates a new rss_feed with the provided attributes" do
          expect { result }.to change { DiscourseRssPolling::RssFeed.count }.by(1)

          feed = result[:rss_feed]
          expect(feed).to have_attributes(
            url: "https://blog.example.com/feed",
            user_id: user.id,
            category_id: category.id,
            tags: "#{tag_1.name},#{tag_2.name}",
            category_filter: "news",
          )
        end
      end

      context "when updating an existing feed" do
        fab!(:rss_feed) { Fabricate(:rss_feed, url: "https://old.example.com/feed", user: user) }

        before { params[:id] = rss_feed.id }

        it { is_expected.to run_successfully }

        it "updates the existing rss_feed" do
          expect { result }.not_to change { DiscourseRssPolling::RssFeed.count }
          expect(rss_feed.reload).to have_attributes(
            url: "https://blog.example.com/feed",
            user_id: user.id,
            category_id: category.id,
            tags: "#{tag_1.name},#{tag_2.name}",
            category_filter: "news",
          )
        end
      end

      context "when discourse_tags is an array of hashes" do
        before { params[:discourse_tags] = [{ "name" => tag_1.name }, { "name" => tag_2.name }] }

        it { is_expected.to run_successfully }

        it "normalizes tags into a comma-separated string" do
          expect(result[:rss_feed].tags).to eq("#{tag_1.name},#{tag_2.name}")
        end
      end

      context "when discourse_tags is blank" do
        before { params[:discourse_tags] = nil }

        it { is_expected.to run_successfully }

        it "stores nil tags" do
          expect(result[:rss_feed].tags).to be_nil
        end
      end
    end
  end
end
