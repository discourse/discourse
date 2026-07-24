# frozen_string_literal: true

RSpec.describe DiscourseRssPolling::RssFeed::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:feed_url) }
    it { is_expected.to validate_presence_of(:author_username) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
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
    let(:dependencies) { { guardian: admin.guardian } }

    context "when the contract is invalid" do
      before { params[:feed_url] = nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the feed_url is only whitespace" do
      before { params[:feed_url] = "   " }

      it { is_expected.to fail_a_contract }
    end

    context "when the feed_url is not http(s)" do
      before { params[:feed_url] = "javascript:alert(1)" }

      it { is_expected.to fail_a_contract }
    end

    context "when updating a feed that does not exist" do
      before { params[:id] = -1 }

      it { is_expected.to fail_to_find_a_model(:rss_feed) }
    end

    context "when the feed_url has surrounding whitespace" do
      before { params[:feed_url] = "  https://blog.example.com/feed  " }

      it { is_expected.to run_successfully }

      it "stores the trimmed url" do
        expect(result[:rss_feed].url).to eq("https://blog.example.com/feed")
      end
    end

    context "when the author does not exist" do
      before { params[:author_username] = "ghost" }

      it { is_expected.to fail_to_find_a_model(:user) }
    end

    context "when the category has an unsatisfied required tag group" do
      before do
        tag_group = Fabricate(:tag_group, tags: [Fabricate(:tag, name: "needed")])
        CategoryRequiredTagGroup.create!(category:, tag_group:, min_count: 1)
        params[:discourse_tags] = []
      end

      it { is_expected.to fail_a_contract }
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

        it "logs the creation as a staff action" do
          expect { result }.to change { UserHistory.count }.by(1)
          expect(UserHistory.last).to have_attributes(
            custom_type: "create_rss_polling_feed",
            acting_user_id: admin.id,
          )
        end

        it "redacts feed-url credentials in the staff action log" do
          params[:feed_url] = "https://blog.example.com/feed?api_key=secret&api_username=system"

          result

          expect(UserHistory.last.details).not_to include("secret")
          expect(UserHistory.last.details).not_to include("api_key")
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

        it "logs the update as a staff action" do
          expect { result }.to change { UserHistory.count }.by(1)
          expect(UserHistory.last.custom_type).to eq("update_rss_polling_feed")
        end
      end

      context "when updating a disabled feed" do
        fab!(:rss_feed) do
          Fabricate(:rss_feed, url: "https://old.example.com/feed", user: user, enabled: false)
        end

        before { params[:id] = rss_feed.id }

        it { is_expected.to run_successfully }

        it "leaves the feed disabled" do
          result
          expect(rss_feed.reload.enabled).to eq(false)
        end
      end

      context "when discourse_tags is an array of hashes" do
        before { params[:discourse_tags] = [{ "name" => tag_1.name }, { "name" => tag_2.name }] }

        it { is_expected.to run_successfully }

        it "normalizes tags into a comma-separated string" do
          expect(result[:rss_feed].tags).to eq("#{tag_1.name},#{tag_2.name}")
        end
      end

      context "when discourse_tags is an array of ActionController::Parameters (form submission)" do
        before do
          params[:discourse_tags] = [
            ActionController::Parameters.new(id: 1, name: tag_1.name),
            ActionController::Parameters.new(id: 2, name: tag_2.name),
          ]
        end

        it "extracts the tag names rather than serializing the objects" do
          expect(result[:rss_feed].tags).to eq("#{tag_1.name},#{tag_2.name}")
        end
      end

      context "when discourse_tags contains a purely numeric tag name" do
        before { params[:discourse_tags] = ["2024"] }

        it "stores the numeric tag name without raising" do
          expect(result[:rss_feed].tags).to eq("2024")
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
