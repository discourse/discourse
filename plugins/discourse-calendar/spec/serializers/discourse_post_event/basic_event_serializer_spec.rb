# frozen_string_literal: true

describe DiscoursePostEvent::BasicEventSerializer do
  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.discourse_post_event_allowed_custom_fields = "team"
    Jobs.run_immediately!
  end

  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category:) }
  fab!(:post) { Fabricate(:post, topic:) }
  fab!(:event) { Fabricate(:event, post:) }

  before { event.update!(custom_fields: { "team" => "rocket" }) }

  it "includes custom_fields so they are readable from event listings" do
    json = described_class.new(event, scope: Guardian.new, root: false).as_json
    expect(json[:custom_fields]["team"]).to eq("rocket")
  end

  it "returns the topic's category_id" do
    json = described_class.new(event, scope: Guardian.new).as_json
    expect(json[:basic_event][:category_id]).to eq(category.id)
  end

  it "serializes without raising when the associated post is gone" do
    event.stubs(:post).returns(nil)

    json = described_class.new(event, scope: Guardian.new).as_json
    expect(json[:basic_event][:category_id]).to be_nil
    expect(json[:basic_event][:post]).to be_nil
  end
end
