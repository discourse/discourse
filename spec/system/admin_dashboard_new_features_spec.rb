# frozen_string_literal: true

describe "Admin Dashboard New Features Page", type: :system do
  let(:new_features_page) { PageObjects::Pages::AdminDashboardNewFeatures.new }
  fab!(:admin)

  before { sign_in(admin) }

  it "displays new features with screenshot taking precedence over emoji" do
    DiscourseUpdates.stubs(:new_features).returns(
      [
        {
          "id" => 7,
          "user_id" => 1,
          "emoji" => "😍",
          "title" => "New feature",
          "description" => "New feature description",
          "link" => "https://meta.discourse.org",
          "tier" => [],
          "discourse_version" => "",
          "created_at" => "2023-11-10T02:52:41.462Z",
          "updated_at" => "2023-11-10T04:28:47.020Z",
          "screenshot_url" =>
            "/uploads/default/original/1X/bab053dc94dc4e0d357b0e777e3357bb1ac99e12.jpeg",
        },
      ],
    )

    new_features_page.visit
    expect(new_features_page).to have_screenshot
    expect(new_features_page).to have_learn_more_link
    expect(new_features_page).to have_no_emoji
  end

  it "displays new features with emoji when no screenshot" do
    DiscourseUpdates.stubs(:new_features).returns(
      [
        {
          "id" => 7,
          "user_id" => 1,
          "emoji" => "😍",
          "title" => "New feature",
          "description" => "New feature description",
          "link" => "https://meta.discourse.org",
          "tier" => [],
          "discourse_version" => "",
          "created_at" => "2023-11-10T02:52:41.462Z",
          "updated_at" => "2023-11-10T04:28:47.020Z",
        },
      ],
    )
    new_features_page.visit
    expect(new_features_page).to have_emoji
    expect(new_features_page).to have_no_screenshot
  end
end
