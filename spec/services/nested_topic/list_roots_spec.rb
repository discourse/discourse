# frozen_string_literal: true

RSpec.describe NestedTopic::ListRoots do
  describe described_class::Contract, type: :model do
    subject { described_class.new(sort: "top", page: 0) }

    it { is_expected.to validate_presence_of(:sort) }
    it { is_expected.to validate_presence_of(:page) }
    it { is_expected.not_to allow_value(-1).for(:page) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:topic) { Fabricate(:topic, user: user) }
    fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

    let(:topic_view) do
      TopicView.new(topic.id, user, skip_custom_fields: true, skip_post_loading: true)
    end
    let(:dependencies) { { guardian: user.guardian, topic_view: topic_view } }
    let(:params) { { sort: "top", page: 0 } }

    before { SiteSetting.nested_replies_enabled = true }

    context "when contract is invalid" do
      let(:params) { { sort: nil, page: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when page 0 with no posts" do
      it { is_expected.to run_successfully }

      it "returns an empty roots list with topic metadata" do
        response = result[:response]
        expect(response[:roots]).to be_empty
        expect(response[:page]).to eq(0)
        expect(response).to have_key(:topic)
        expect(response).to have_key(:op_post)
        expect(response).to have_key(:sort)
        expect(response).to have_key(:message_bus_last_id)
      end
    end

    context "when page 0 with root posts" do
      fab!(:root_post) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1) }

      it { is_expected.to run_successfully }

      it "includes root posts and topic metadata in the response" do
        response = result[:response]
        expect(response[:roots]).to be_present
        expect(response[:roots].first[:id]).to eq(root_post.id)
        expect(response[:topic]).to be_present
        expect(response[:op_post]).to be_present
        expect(response[:sort]).to eq("top")
        expect(response[:message_bus_last_id]).to be_an(Integer)
      end
    end

    it "marks an exact full root page as the final page" do
      stub_const(NestedReplies::TreeLoader, :ROOTS_PER_PAGE, 2) do
        2.times { Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1) }

        expect(result[:response][:roots].length).to eq(2)
        expect(result[:response][:has_more_roots]).to eq(false)
      end
    end

    context "when page is greater than 0" do
      let(:params) { { sort: "top", page: 1 } }

      it { is_expected.to run_successfully }

      it "does not include topic metadata in the response" do
        response = result[:response]
        expect(response).to have_key(:roots)
        expect(response).not_to have_key(:topic)
        expect(response).not_to have_key(:op_post)
        expect(response).not_to have_key(:sort)
      end
    end

    context "when there are pinned roots on page 0" do
      fab!(:root_post) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1) }
      fab!(:pinned_post) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1) }

      before { Fabricate(:nested_topic, topic: topic).update!(pinned_post_ids: [pinned_post.id]) }

      it { is_expected.to run_successfully }

      it "promotes the pinned post to the front of the roots list" do
        response = result[:response]
        root_ids = response[:roots].map { |r| r[:id] }
        expect(root_ids.first).to eq(pinned_post.id)
      end

      it "includes pinned_post_ids in the response" do
        response = result[:response]
        expect(response[:pinned_post_ids]).to include(pinned_post.id)
      end
    end

    context "with root_summary" do
      it "is omitted on page 1+" do
        result =
          described_class.call(
            params: {
              sort: "top",
              page: 1,
            },
            guardian: user.guardian,
            topic_view: topic_view,
          )
        expect(result[:response]).not_to have_key(:root_summary)
      end

      it "includes page_size so the client can compute target pages" do
        summary = result[:response][:root_summary]
        expect(summary[:page_size]).to eq(NestedReplies::TreeLoader::ROOTS_PER_PAGE)
      end

      it "includes page_count" do
        summary = result[:response][:root_summary]
        expect(summary[:page_count]).to eq(0)
      end

      it "includes pinned_count so the client can offset position math" do
        root_a = Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1)
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1)
        Fabricate(:nested_topic, topic: topic).update!(pinned_post_ids: [root_a.id])

        summary = result[:response][:root_summary]
        expect(summary[:pinned_count]).to eq(1)
      end

      it "reports pinned_count as 0 when nothing is pinned" do
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1)
        summary = result[:response][:root_summary]
        expect(summary[:pinned_count]).to eq(0)
      end
    end

    context "when there are pinned roots on page 1" do
      let(:params) { { sort: "top", page: 1 } }

      fab!(:root_post) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1) }

      before { Fabricate(:nested_topic, topic: topic).update!(pinned_post_ids: [root_post.id]) }

      it { is_expected.to run_successfully }

      it "does not promote pinned posts" do
        response = result[:response]
        expect(response).not_to have_key(:pinned_post_ids)
      end

      it "excludes pinned posts from paginated results" do
        response = result[:response]
        root_ids = response[:roots].map { |r| r[:id] }
        expect(root_ids).not_to include(root_post.id)
      end
    end
  end
end
