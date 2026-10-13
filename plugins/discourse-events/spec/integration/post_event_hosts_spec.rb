# frozen_string_literal: true

RSpec.describe "post-event hosts" do
  before do
    Jobs.run_immediately!
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  fab!(:admin)

  it "persists ordered hosts from event attributes" do
    first_host = Fabricate(:user)
    second_host = Fabricate(:user)

    post = PostCreator.create!(admin, title: "Community meetup", raw: <<~RAW)
          [event start="#{1.day.from_now.iso8601}" hosts="#{second_host.username},#{first_host.username}"]
          [/event]
        RAW

    event = post.reload.event
    expect(event.hosts).to eq([second_host, first_host])

    json = DiscourseEvents::Events::EventSerializer.new(event, scope: Guardian.new).as_json
    expect(json.dig(:event, :hosts).as_json.map { |host| host[:username] }).to eq(
      [second_host.username, first_host.username],
    )
  end

  it "removes hosts when the event attribute is removed" do
    host = Fabricate(:user)
    post =
      PostCreator.create!(
        admin,
        title: "Community meetup",
        raw: "[event start=\"#{1.day.from_now.iso8601}\" hosts=\"#{host.username}\"]\n[/event]",
      )

    PostRevisor.new(post).revise!(
      admin,
      raw: "[event start=\"#{1.day.from_now.iso8601}\"]\n[/event]",
    )

    expect(post.reload.event.hosts).to be_empty
  end

  it "rejects a host who cannot see the event category" do
    group = Fabricate(:group)
    category = Fabricate(:private_category, group:)
    host = Fabricate(:user)

    expect {
      PostCreator.create!(
        admin,
        category: category.id,
        title: "Private community meetup",
        raw: "[event start=\"#{1.day.from_now.iso8601}\" hosts=\"#{host.username}\"]\n[/event]",
      )
    }.to raise_error(I18n.t("discourse_post_event.errors.models.event.invalid_hosts"))
  end
end
