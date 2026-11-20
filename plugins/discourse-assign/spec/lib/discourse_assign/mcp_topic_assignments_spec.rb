# frozen_string_literal: true

describe DiscourseAssign::McpTopicAssignments do
  it "batches assignments and category permissions across the topic page" do
    user = Fabricate(:user)
    group = Fabricate(:group)
    group.add(user)
    SiteSetting.assign_enabled = true
    SiteSetting.assigns_public = false
    topics =
      8.times.map do
        category = Fabricate(:category)
        category.custom_fields[
          DiscourseAssign::AssignmentPermissions::CATEGORY_ADDITIONAL_ASSIGN_ALLOWED_GROUPS
        ] = group.id.to_s
        category.save_custom_fields
        topic = Fabricate(:topic, category:)
        Fabricate(:topic_assignment, topic:, assigned_to: user)
        topic
      end

    small_queries =
      track_sql_queries do
        expect(
          described_class.for_topics(topics.first(1), guardian: Guardian.new(user)).keys,
        ).to eq([topics.first.id])
      end
    page_queries =
      track_sql_queries do
        expect(
          described_class.for_topics(topics, guardian: Guardian.new(user)).keys,
        ).to contain_exactly(*topics.map(&:id))
      end
    expect(page_queries.size).to be <= small_queries.size
  end
end
