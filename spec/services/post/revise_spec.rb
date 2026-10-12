# frozen_string_literal: true

RSpec.describe Post::Revise do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }

    it { is_expected.not_to allow_values(nil, [], "invalid").for(:changes) }

    it do
      is_expected.not_to allow_values(
        { tags: [{ id: "1.5" }] },
        { original_tags: [{ id: false }] },
        { tags: ["existing-tag", { id: 1 }] },
      ).for(:changes)
    end

    it do
      is_expected.to allow_values(
        { tags: nil, original_tags: nil },
        { tags: ["existing-tag"], original_tags: ["previous-tag"] },
        { tags: [{ id: 1 }, { id: "2", name: "another-tag" }, { name: "new-tag" }] },
      ).for(:changes)
    end

    context "with a post ID" do
      subject(:contract) { described_class.new(post_id: 1) }

      it { is_expected.to validate_absence_of(:topic_id) }
    end

    context "with a topic ID" do
      subject(:contract) { described_class.new(topic_id: 1) }

      it { is_expected.not_to validate_presence_of(:post_id) }
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:topic, :topic_with_op)

    let(:post) { topic.first_post }
    let(:params) { { post_id: post.id, changes: } }
    let(:dependencies) { { guardian: acting_user.guardian, editor: acting_user } }
    let(:changes) { { raw: "The corrected text of this post." } }

    context "without a post or topic ID" do
      let(:params) { { changes: } }

      it { is_expected.to fail_a_contract }
    end

    context "when the post is missing" do
      let(:params) { { post_id: 0, changes: } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the actor cannot edit the topic" do
      fab!(:acting_user, :user)

      let(:params) { { topic_id: topic.id, changes: { title: "A corrected topic title" } } }

      it "preserves the topic title" do
        expect { expect(result).to fail_a_policy(:can_edit_topic_record) }.not_to change {
          topic.reload.title
        }
      end
    end

    context "when the actor cannot edit the post" do
      fab!(:acting_user, :user)

      it "leaves the post unchanged" do
        expect { expect(result).to fail_a_policy(:can_edit_post) }.not_to change { post.reload.raw }
      end
    end

    context "when the actor cannot edit tags" do
      fab!(:acting_user) { Fabricate(:user, refresh_auto_groups: true) }
      fab!(:tag)

      let(:changes) { super().merge(tags: [{ id: tag.id }]) }

      before do
        SiteSetting.tagging_enabled = true
        SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
        post.update!(user: acting_user)
      end

      it "rejects the tags before changing the body" do
        expect { expect(result).to fail_a_policy(:can_edit_tags) }.not_to change { post.reload.raw }
        expect(topic.reload.tags).to be_empty
      end
    end

    context "when the original text is stale" do
      let(:changes) { super().merge(original_text: "An earlier version of this post.") }

      it "preserves the current post" do
        expect { expect(result).to fail_a_step(:check_edit_conflicts) }.not_to change {
          post.reload.raw
        }
      end
    end

    context "when the destination category is forbidden" do
      fab!(:acting_user) { Fabricate(:user, refresh_auto_groups: true) }
      fab!(:topic) { Fabricate(:topic_with_op, user: acting_user) }
      fab!(:category) { Fabricate(:private_category, group: Group[:staff]) }

      let(:changes) { super().merge(category_id: category.id) }

      before { post.update!(user: acting_user) }

      it "rejects the category change before changing the body" do
        expect { expect(result).to fail_a_step(:validate_category_change) }.not_to change {
          post.reload.raw
        }
        expect(topic.reload.category_id).not_to eq(category.id)
      end
    end

    context "when the revised body is invalid" do
      let(:changes) { { raw: "" } }

      it "preserves the body and revision history" do
        expect { expect(result).to fail_a_step(:revise_post) }.not_to change {
          [post.reload.raw, post.revisions.count]
        }
      end
    end

    context "when the edit is valid" do
      let(:changes) { super().merge(title: "A corrected topic title") }

      it "saves the body and topic title together" do
        expect(result).to run_successfully
        expect(post.reload.raw).to eq(changes[:raw])
        expect(topic.reload.title).to eq(changes[:title])
      end
    end

    context "when only the topic is being edited" do
      let(:params) { { topic_id: topic.id, changes: } }
      let(:changes) { { title: "A corrected topic title" } }

      it "updates the title and preserves the post body" do
        expect { expect(result).to run_successfully }.not_to change { post.reload.raw }
        expect(topic.reload.title).to eq(changes[:title])
      end
    end

    context "when the submitted content is unchanged" do
      let(:changes) { { raw: post.raw, title: topic.title } }

      it "succeeds without creating a revision" do
        expect { expect(result).to run_successfully }.not_to change { post.revisions.count }
      end
    end
  end
end
