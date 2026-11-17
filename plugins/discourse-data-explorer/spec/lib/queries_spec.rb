# frozen_string_literal: true

describe DiscourseDataExplorer::Queries do
  fab!(:user)
  fab!(:post)
  fab!(:group)

  before { SiteSetting.data_explorer_enabled = true }

  describe ".default" do
    it "includes distributed traffic scores and reasons in the detailed crawler report" do
      event = Fabricate(:browser_pageview_event, score: 60, created_at: 1.hour.ago)
      BrowserPageviewEventScore.create!(event: event, distributed_traffic_score: 60)
      attributes = described_class.default.fetch("-43")
      query =
        DiscourseDataExplorer::Query.new(id: -43, name: attributes[:name], sql: attributes["sql"])

      result =
        DiscourseDataExplorer::DataExplorer.run_query(query, {}, current_user: user, limit: 10)

      expect(result[:error]).to be_nil
      row = result[:pg_result].to_a.first
      expect(row["distributed_traffic"].to_i).to eq(60)
      expect(row["reasons"]).to include("distributed traffic (+60)")
    end

    # rubocop:disable Discourse/NoIterationOverRSpecDefinitions
    described_class.default.each do |id, attributes|
      it "runs #{attributes[:name]} with its declared parameters" do
        query =
          DiscourseDataExplorer::Query.new(id: id, name: attributes[:name], sql: attributes["sql"])
        values = {
          "start_date" => 30.days.ago.to_date.iso8601,
          "end_date" => Date.current.iso8601,
          "group_name" => group.name,
          "report_id" => "1",
          "poll_name" => "poll",
          "post_id" => post.id.to_s,
          "topic_id" => post.topic_id.to_s,
          "category_id" => post.topic.category_id.to_s,
          "user" => user.id.to_s,
          "notification_level" => "3",
          "silenced_by" => user.username,
          "suspended_by" => user.username,
        }
        params =
          values.slice(*query.params.reject { |param| param.default.present? }.map(&:identifier))
        variants = [params]
        optional_params = query.params.select(&:nullable).map(&:identifier)
        variants << params.except(*optional_params) if optional_params.any?

        variants.each do |query_params|
          result =
            DiscourseDataExplorer::DataExplorer.run_query(
              query,
              query_params,
              current_user: user,
              limit: 10,
            )

          expect(result[:error]).to be_nil,
          "#{attributes[:name]} with #{query_params.inspect}: #{result[:error]}"
          expect(result[:pg_result]).to be_a(PG::Result)
        end
      end
    end
    # rubocop:enable Discourse/NoIterationOverRSpecDefinitions
  end
end
