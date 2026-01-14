# frozen_string_literal: true

describe "Group timezones feature", type: :system do
  fab!(:group) { Fabricate(:group, name: "test-group") }

  fab!(:users) do
    Fabricate
      .times(5, :user)
      .each do |user|
        user.user_option.timezone = "America/New_York"
        user.user_option.save!
        group.add(user)
      end
  end

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
  end

  let(:post) { create_post(raw: <<~RAW) }
    [timezones group="test-group"]
    [/timezones]
  RAW

  it "renders successfully" do
    visit(post.url)
    expect(page).to have_selector(".group-timezones")
    expect(page).to have_selector(".group-timezones-member", count: 5)
  end
end
