# frozen_string_literal: true

RSpec.describe TopicViewSerializer do
  fab!(:user)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  let(:guardian) { Guardian.new(user) }

  include_context "with group that is allowed to assign"

  before do
    SiteSetting.assign_enabled = true
    assign_allowed_group.add(user)
  end

  it "includes assigned user in serializer" do
    Assigner.new(topic, user).assign(user)
    serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
    expect(serializer.as_json[:topic_view][:assigned_to_user][:name]).to eq(user.name)
    expect(serializer.as_json[:topic_view][:assigned_to_user][:username]).to eq(user.username)
    expect(serializer.as_json[:topic_view][:assigned_to_group]).to be nil
  end

  it "omits the assigned user's name when names are disabled" do
    SiteSetting.enable_names = false
    Assigner.new(topic, user).assign(user)

    assigned_user =
      TopicViewSerializer.new(TopicView.new(topic), scope: guardian).as_json[:topic_view][
        :assigned_to_user
      ]

    expect(assigned_user[:username]).to eq(user.username)
    expect(assigned_user).not_to have_key(:name)
  end

  it "includes assigned group in serializer" do
    Assigner.new(topic, user).assign(assign_allowed_group)
    serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
    expect(serializer.as_json[:topic_view][:assigned_to_group][:name]).to eq(
      assign_allowed_group.name,
    )
    expect(serializer.as_json[:topic_view][:assigned_to_user]).to be nil
  end

  it "includes note in serializer" do
    Assigner.new(topic, user).assign(user, note: "note me down")
    serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
    expect(serializer.as_json[:topic_view][:assignment_note]).to eq("note me down")
  end

  it "includes indirectly_assigned_to notes in serializer" do
    Assigner.new(post, user).assign(user, note: "note me down")
    serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
    expect(
      serializer.as_json[:topic_view][:indirectly_assigned_to][post.id][:assignment_note],
    ).to eq("note me down")
  end

  context "with multiple direct topic assignments" do
    fab!(:other_assignee, :moderator)

    let!(:first_assignment) do
      Fabricate(:topic_assignment, topic: topic, assigned_to: user, note: "Review references")
    end
    let!(:second_assignment) do
      Fabricate(
        :topic_assignment,
        topic: topic,
        assigned_to: other_assignee,
        note: "Check publication details",
      )
    end

    before { SiteSetting.assign_allow_multiple_topic_assignees = true }

    it "includes each assignment's identity and note for an authorized viewer" do
      serialized =
        TopicViewSerializer.new(TopicView.new(topic), scope: guardian).as_json[:topic_view]

      expect(serialized[:topic_assignments]).to contain_exactly(
        include(id: first_assignment.id, note: first_assignment.note),
        include(id: second_assignment.id, note: second_assignment.note),
      )
    end

    it "omits private assignment metadata for an ordinary viewer" do
      viewer = Fabricate(:user)
      serialized =
        TopicViewSerializer.new(TopicView.new(topic), scope: viewer.guardian).as_json[:topic_view]

      expect(serialized).not_to have_key(:topic_assignments)
      expect(serialized.to_json).not_to include(first_assignment.note, second_assignment.note)
    end

    it "exposes public assignments to an ordinary viewer" do
      SiteSetting.assigns_public = true
      viewer = Fabricate(:user)
      serialized =
        TopicViewSerializer.new(TopicView.new(topic), scope: viewer.guardian).as_json[:topic_view]

      expect(serialized[:topic_assignments].pluck(:id)).to contain_exactly(
        first_assignment.id,
        second_assignment.id,
      )
    end

    it "includes the complete collection on list, suggested, search, and flagged topic surfaces" do
      [
        TopicListItemSerializer,
        SuggestedTopicSerializer,
        SearchTopicListItemSerializer,
        FlaggedTopicSerializer,
      ].each do |serializer_class|
        serialized = serializer_class.new(topic, scope: guardian, root: false).as_json

        aggregate_failures(serializer_class.name) do
          expect(serialized[:topic_assignments].pluck(:id)).to contain_exactly(
            first_assignment.id,
            second_assignment.id,
          )
        end
      end
    end

    it "omits private collection metadata from other topic surfaces for ordinary viewers" do
      viewer = Fabricate(:user)

      [
        TopicListItemSerializer,
        SuggestedTopicSerializer,
        SearchTopicListItemSerializer,
        FlaggedTopicSerializer,
      ].each do |serializer_class|
        serialized = serializer_class.new(topic, scope: viewer.guardian, root: false).as_json

        aggregate_failures(serializer_class.name) do
          expect(serialized).not_to have_key(:topic_assignments)
          expect(serialized.to_json).not_to include(first_assignment.note, second_assignment.note)
        end
      end
    end
  end

  context "when status is enabled" do
    before { SiteSetting.enable_assign_status = true }

    it "includes status in serializer" do
      Assigner.new(topic, user).assign(user, status: "Done")
      serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
      expect(serializer.as_json[:topic_view][:assignment_status]).to eq("Done")
    end

    it "includes indirectly_assigned_to status in serializer" do
      Assigner.new(post, user).assign(user, status: "Done")
      serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
      expect(
        serializer.as_json[:topic_view][:indirectly_assigned_to][post.id][:assignment_status],
      ).to eq("Done")
    end
  end

  context "when status is disabled" do
    before { SiteSetting.enable_assign_status = false }

    it "doesn't include status in serializer" do
      Assigner.new(topic, user).assign(user, status: "Done")
      serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
      expect(serializer.as_json[:topic_view][:assignment_status]).not_to eq("Done")
    end

    it "doesn't include indirectly_assigned_to status in serializer" do
      Assigner.new(post, user).assign(user, status: "Done")
      serializer = TopicViewSerializer.new(TopicView.new(topic), scope: guardian)
      expect(
        serializer.as_json[:topic_view][:indirectly_assigned_to][post.id][:assignment_status],
      ).not_to eq("Done")
    end
  end
end
