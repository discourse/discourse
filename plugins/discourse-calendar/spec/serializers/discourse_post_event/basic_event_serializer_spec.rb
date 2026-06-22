# frozen_string_literal: true

describe DiscoursePostEvent::BasicEventSerializer do
  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.discourse_post_event_allowed_custom_fields = "team"
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
end
