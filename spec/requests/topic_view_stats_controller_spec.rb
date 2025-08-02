# frozen_string_literal: true

describe TopicViewStatsController do
  fab!(:topic)

  it "will error if accessed on require login sites" do
    SiteSetting.login_required = true
    get "/t/#{topic.id}/view-stats.json"
    expect(response.status).to eq(403)
  end

  it "will not allow access to private topics" do
    topic.category.update!(read_restricted: true)

    get "/t/#{topic.id}/view-stats.json"
    expect(response.status).to eq(403)
  end

  it "will raise correct errors if any param is invalid" do
    get "/t/999999999999999999999999999999990000009/view-stats.json"
    expect(response.status).to eq(404)
  end

  it "will return an error if from and to are not valid dates" do
    get "/t/#{topic.id}/view-stats.json?from=abc&to=xxx"

    expect(response.status).to eq(422)
  end

  it "will return view stats for public topics" do
    freeze_time "2021-01-01 12:00"

    TopicViewStat.create!(
      topic_id: topic.id,
      viewed_at: Date.yesterday,
      anonymous_views: 2,
      logged_in_views: 3,
    )

    TopicViewStat.create!(
      topic_id: topic.id,
      viewed_at: Date.today,
      anonymous_views: 1,
      logged_in_views: 2,
    )

    get "/t/#{topic.id}/view-stats.json"
    expect(response.status).to eq(200)

    expected = {
      "topic_id" => topic.id,
      "stats" => [
        { "viewed_at" => "2020-12-31", "views" => 5 },
        { "viewed_at" => "2021-01-01", "views" => 3 },
      ],
    }

    expect(response.parsed_body).to eq(expected)

    get "/t/#{topic.id}/view-stats.json?from=2019-12-31&to=2019-12-31"
    expect(response.parsed_body).to eq({ "topic_id" => topic.id, "stats" => [] })

    get "/t/#{topic.id}/view-stats.json?from=2000-12-31&to=2020-12-31"
    expected = {
      "topic_id" => topic.id,
      "stats" => [{ "viewed_at" => "2020-12-31", "views" => 5 }],
    }
    expect(response.parsed_body).to eq(expected)

    get "/t/#{topic.id}/view-stats.json?from=2020-12-31&to=2020-12-31"
    expect(response.parsed_body).to eq(expected)
  end
end
