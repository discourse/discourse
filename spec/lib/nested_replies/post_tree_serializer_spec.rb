# frozen_string_literal: true

RSpec.describe NestedReplies::PostTreeSerializer do
  fab!(:user)
  fab!(:ignored_user, :user)
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  let(:topic_view) do
    TopicView.new(topic.id, user, skip_custom_fields: true, skip_post_loading: true)
  end

  before { SiteSetting.nested_replies_enabled = true }

  def serializer_for(viewer)
    described_class.new(topic: topic, topic_view: topic_view, guardian: Guardian.new(viewer))
  end

  describe "#serialize_post" do
    fab!(:reply) do
      Fabricate(:post, topic: topic, user: ignored_user, reply_to_post_number: 1, raw: "secret")
    end

    context "when the viewer has ignored the author" do
      before { Fabricate(:ignored_user, user: user, ignored_user: ignored_user) }

      it "marks it as an ignored_post_placeholder, clears content, keeps metadata" do
        json = serializer_for(user).serialize_post(reply, {})

        expect(json[:ignored_post_placeholder]).to eq(true)
        expect(json[:cooked]).to eq("")
        expect(json[:raw]).to be_nil
        expect(json[:actions_summary]).to eq([])
        expect(json[:username]).to eq(ignored_user.username)
        expect(json).to include(:id, :post_number, :reply_to_post_number, :avatar_template)
      end
    end

    context "when the viewer has not ignored the author" do
      it "returns the full post JSON" do
        json = serializer_for(user).serialize_post(reply, {})

        expect(json).not_to have_key(:ignored_post_placeholder)
        expect(json[:cooked]).to include("secret")
      end
    end

    context "when the viewer is anonymous" do
      it "returns the full post JSON" do
        json = serializer_for(nil).serialize_post(reply, {})

        expect(json).not_to have_key(:ignored_post_placeholder)
        expect(json[:cooked]).to include("secret")
      end
    end

    context "when the ignored author wrote the OP (post_number == 1)" do
      before { Fabricate(:ignored_user, user: user, ignored_user: ignored_user) }

      it "does not placeholder the OP (client-side firstPost handles it)" do
        op.update!(user: ignored_user)

        json = serializer_for(user).serialize_post(op, {})

        expect(json).not_to have_key(:ignored_post_placeholder)
        expect(json[:cooked]).to be_present
      end
    end

    context "when the post is both deleted and from an ignored author" do
      before { Fabricate(:ignored_user, user: user, ignored_user: ignored_user) }

      it "prefers the deleted_post_placeholder path" do
        reply.trash!(user)

        json = serializer_for(user).serialize_post(reply.reload, {})

        expect(json[:deleted_post_placeholder]).to eq(true)
        expect(json).not_to have_key(:ignored_post_placeholder)
      end
    end
  end
end
