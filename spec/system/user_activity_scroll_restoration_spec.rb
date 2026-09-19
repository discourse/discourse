# frozen_string_literal: true

describe "User activity scroll restoration" do
  before_all { UserActionManager.enable }

  fab!(:user)

  # 40 replies: the stream serves 30 per page, so the rest arrive via infinite scroll
  fab!(:topics) do
    Fabricate
      .times(5, :topic)
      .each do |topic|
        Fabricate
          .times(9, :post, topic:, user:)
          .each { |post| UserActionManager.post_created(post) }
      end
  end

  let(:activity_stream) { PageObjects::Pages::UserActivityStream.new }

  it "takes the user back to where they were reading after they open a post and go back" do
    activity_stream.visit_replies(user)
    expect(activity_stream).to have_items(count: 30)

    activity_stream.scroll_to_bottom
    expect(activity_stream).to have_items(count: 40)

    activity_stream.scroll_to_item(35)
    position = activity_stream.scroll_position

    activity_stream.open_item(36)
    expect(page).to have_css("#topic-title")

    page.go_back
    expect(activity_stream).to have_items(count: 40)

    try_until_success(reason: "scroll position is restored") do
      expect(activity_stream.scroll_position).to be_within(20).of(position)
    end
  end
end
