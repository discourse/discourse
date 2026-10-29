# frozen_string_literal: true

describe DiscourseDataExplorer::Queries do
  fab!(:user)
  fab!(:post)
  fab!(:group)

  before { SiteSetting.data_explorer_enabled = true }

  describe ".default" do
    shared_examples "queries for id and attributes" do |id, attributes|
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

    include_examples "queries for id and attributes", ["-1", described_class.default.fetch("-1")]
    include_examples "queries for id and attributes", ["-2", described_class.default.fetch("-2")]
    include_examples "queries for id and attributes", ["-3", described_class.default.fetch("-3")]
    include_examples "queries for id and attributes", ["-4", described_class.default.fetch("-4")]
    include_examples "queries for id and attributes", ["-5", described_class.default.fetch("-5")]
    include_examples "queries for id and attributes", ["-6", described_class.default.fetch("-6")]
    include_examples "queries for id and attributes", ["-7", described_class.default.fetch("-7")]
    include_examples "queries for id and attributes", ["-8", described_class.default.fetch("-8")]
    include_examples "queries for id and attributes", ["-9", described_class.default.fetch("-9")]
    include_examples "queries for id and attributes", ["-10", described_class.default.fetch("-10")]
    include_examples "queries for id and attributes", ["-11", described_class.default.fetch("-11")]
    include_examples "queries for id and attributes", ["-12", described_class.default.fetch("-12")]
    include_examples "queries for id and attributes", ["-13", described_class.default.fetch("-13")]
    include_examples "queries for id and attributes", ["-14", described_class.default.fetch("-14")]
    include_examples "queries for id and attributes", ["-15", described_class.default.fetch("-15")]
    include_examples "queries for id and attributes", ["-16", described_class.default.fetch("-16")]
    include_examples "queries for id and attributes", ["-17", described_class.default.fetch("-17")]
    include_examples "queries for id and attributes", ["-18", described_class.default.fetch("-18")]
    include_examples "queries for id and attributes", ["-19", described_class.default.fetch("-19")]
    include_examples "queries for id and attributes", ["-20", described_class.default.fetch("-20")]
    include_examples "queries for id and attributes", ["-21", described_class.default.fetch("-21")]
    include_examples "queries for id and attributes", ["-22", described_class.default.fetch("-22")]
    include_examples "queries for id and attributes", ["-23", described_class.default.fetch("-23")]
    include_examples "queries for id and attributes", ["-24", described_class.default.fetch("-24")]
    include_examples "queries for id and attributes", ["-25", described_class.default.fetch("-25")]
    include_examples "queries for id and attributes", ["-26", described_class.default.fetch("-26")]
    include_examples "queries for id and attributes", ["-27", described_class.default.fetch("-27")]
    include_examples "queries for id and attributes", ["-28", described_class.default.fetch("-28")]
    include_examples "queries for id and attributes", ["-29", described_class.default.fetch("-29")]
    include_examples "queries for id and attributes", ["-30", described_class.default.fetch("-30")]
    include_examples "queries for id and attributes", ["-31", described_class.default.fetch("-31")]
    include_examples "queries for id and attributes", ["-32", described_class.default.fetch("-32")]
    include_examples "queries for id and attributes", ["-33", described_class.default.fetch("-33")]
    include_examples "queries for id and attributes", ["-34", described_class.default.fetch("-34")]
    include_examples "queries for id and attributes", ["-35", described_class.default.fetch("-35")]
    include_examples "queries for id and attributes", ["-36", described_class.default.fetch("-36")]
    include_examples "queries for id and attributes", ["-37", described_class.default.fetch("-37")]
    include_examples "queries for id and attributes", ["-38", described_class.default.fetch("-38")]
    include_examples "queries for id and attributes", ["-39", described_class.default.fetch("-39")]
    include_examples "queries for id and attributes", ["-40", described_class.default.fetch("-40")]
    include_examples "queries for id and attributes", ["-41", described_class.default.fetch("-41")]
    include_examples "queries for id and attributes", ["-42", described_class.default.fetch("-42")]
    include_examples "queries for id and attributes", ["-43", described_class.default.fetch("-43")]
    include_examples "queries for id and attributes", ["-44", described_class.default.fetch("-44")]
    include_examples "queries for id and attributes", ["-45", described_class.default.fetch("-45")]
    include_examples "queries for id and attributes", ["-46", described_class.default.fetch("-46")]
    include_examples "queries for id and attributes", ["-47", described_class.default.fetch("-47")]
    include_examples "queries for id and attributes", ["-48", described_class.default.fetch("-48")]
  end
end
