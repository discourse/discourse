# frozen_string_literal: true

RSpec.describe Topic::Revise do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }

    it { is_expected.not_to allow_value(nil).for(:changes) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:topic, :topic_with_op)

    let(:post) { topic.first_post }
    let(:params) { { topic_id: topic.id, changes: } }
    let(:dependencies) { { guardian: acting_user.guardian, editor: acting_user } }
    let(:changes) { { title: "A corrected topic title" } }

    context "without a topic ID" do
      let(:params) { { changes: } }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic is deleted" do
      before { topic.trash! }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the actor cannot edit the topic" do
      fab!(:acting_user, :user)

      it "preserves the topic title" do
        expect { expect(result).to fail_a_policy(:can_edit_topic) }.not_to change {
          topic.reload.title
        }
      end
    end

    context "when the actor can edit topic details but not the post" do
      fab!(:acting_user) { Fabricate(:user, refresh_auto_groups: true) }

      let(:changes) { super().merge(raw: "This body change must be ignored.") }

      before do
        editors = Fabricate(:group, users: [acting_user])
        SiteSetting.edit_all_topic_groups = editors.id.to_s
      end

      it "updates the title and preserves the post body" do
        expect { expect(result).to run_successfully }.not_to change { post.reload.raw }
        expect(topic.reload.title).to eq(changes[:title])
      end
    end

    context "when a shared draft title is stale" do
      let(:destination) { Fabricate(:category) }
      let(:changes) do
        super().merge(category_id: destination.id, original_title: "An earlier topic title")
      end

      it "rejects the edit without changing the destination or title" do
        shared_draft = Fabricate(:shared_draft, topic:)

        expect { expect(result).to fail_a_step(:check_edit_conflicts) }.not_to change {
          [shared_draft.reload.category_id, topic.reload.title]
        }
      end
    end

    context "when the shared draft destination is explicitly nil" do
      let(:changes) { { category_id: nil } }

      it "rejects the destination without changing it" do
        shared_draft = Fabricate(:shared_draft, topic:)

        expect { expect(result).to fail_a_step(:validate_destination) }.not_to change {
          shared_draft.reload.category_id
        }
      end
    end

    context "when only the shared draft destination changes" do
      let(:destination) { Fabricate(:category) }
      let(:changes) { { category_id: destination.id } }

      it "updates the destination without revising the post or advancing the draft sequence" do
        shared_draft = Fabricate(:shared_draft, topic:)
        DraftSequence.next!(acting_user, topic.draft_key)

        expect { expect(result).to run_successfully }.not_to change {
          [post.revisions.count, DraftSequence.current(acting_user, topic.draft_key)]
        }
        expect(shared_draft.reload.category_id).to eq(destination.id)
      end
    end

    context "when a shared draft destination and title change" do
      let(:destination) { Fabricate(:category) }
      let(:changes) { super().merge(category_id: destination.id) }

      it "saves both changes while preserving the topic category and post body" do
        shared_draft = Fabricate(:shared_draft, topic:)

        expect { expect(result).to run_successfully }.not_to change {
          [topic.reload.category_id, post.reload.raw]
        }
        expect(shared_draft.reload.category_id).to eq(destination.id)
        expect(topic.reload.title).to eq(changes[:title])
      end
    end

    context "when the title changes" do
      let(:events) { DiscourseEvent.track_events(:post_edited) { result } }

      it "records the revision and emits the post edited event" do
        original_title = topic.title

        events

        expect(result).to run_successfully
        expect(post.revisions.last.modifications["title"]).to eq([original_title, changes[:title]])
        expect(events).to contain_exactly(include(event_name: :post_edited, params: include(post)))
      end
    end

    context "when a shared draft title revision is invalid" do
      let(:destination) { Fabricate(:category) }
      let(:changes) { { title: "", category_id: destination.id } }

      it "rolls back the destination and preserves the title and revision history" do
        shared_draft = Fabricate(:shared_draft, topic:)

        expect { expect(result).to fail_a_step(:revise_post) }.not_to change {
          [shared_draft.reload.category_id, topic.reload.title, post.revisions.count]
        }
        expect(result[:topic].errors).to be_present
      end
    end
  end
end
