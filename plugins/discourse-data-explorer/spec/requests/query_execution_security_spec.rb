# frozen_string_literal: true

describe "Data Explorer group report query execution" do
  fab!(:user) do
    Fabricate(:user, username: SecureRandom.hex(8), email: "#{SecureRandom.hex(8)}@example.com")
  end
  fab!(:group) { Fabricate(:group, name: SecureRandom.hex(8), users: [user]) }

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in(user)
  end

  def create_report
    query = DiscourseDataExplorer::Query.create!(name: "Parameterized Query", sql: <<~SQL)
          -- [params]
          -- string :value
          SELECT $sql$:value$sql$ AS value
        SQL
    query.query_groups.create!(group: group)
    query
  end

  it "rejects a group member's parameter inside a dollar-quoted literal" do
    victim =
      Fabricate(:user, username: SecureRandom.hex(8), email: "#{SecureRandom.hex(8)}@example.com")
    query = create_report
    payload = <<~SQL.chomp
      harmless$sql$) SELECT * FROM query;
      WITH query AS (
      SELECT email FROM user_emails WHERE user_id = #{victim.id} --
    SQL

    post "/g/#{group.name}/reports/#{query.id}/run.json", params: { params: { value: payload } }

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to eq(
      [
        "DiscourseDataExplorer::ValidationError: Parameters cannot be used inside dollar-quoted literals",
      ],
    )
    expect(response.body).not_to include(victim.email)
  end

  it "rejects a benign group report parameter inside a dollar-quoted literal" do
    query = create_report

    post "/g/#{group.name}/reports/#{query.id}/run.json",
         params: {
           params: {
             value: "expected value",
           },
         }

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to eq(
      [
        "DiscourseDataExplorer::ValidationError: Parameters cannot be used inside dollar-quoted literals",
      ],
    )
  end
end
