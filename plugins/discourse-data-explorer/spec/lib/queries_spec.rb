# frozen_string_literal: true

describe DiscourseDataExplorer::Queries do
  fab!(:user)
  fab!(:post)
  fab!(:group)

  before { SiteSetting.data_explorer_enabled = true }

  describe ".default" do
    shared_examples "a runnable default query" do |id, attributes|
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

    it_behaves_like "a runnable default query", ["-1", described_class.default.fetch("-1")]
    it_behaves_like "a runnable default query", ["-2", described_class.default.fetch("-2")]
    it_behaves_like "a runnable default query", ["-3", described_class.default.fetch("-3")]
    it_behaves_like "a runnable default query", ["-4", described_class.default.fetch("-4")]
    it_behaves_like "a runnable default query", ["-5", described_class.default.fetch("-5")]
    it_behaves_like "a runnable default query", ["-6", described_class.default.fetch("-6")]
    it_behaves_like "a runnable default query", ["-7", described_class.default.fetch("-7")]
    it_behaves_like "a runnable default query", ["-8", described_class.default.fetch("-8")]
    it_behaves_like "a runnable default query", ["-9", described_class.default.fetch("-9")]
    it_behaves_like "a runnable default query", ["-10", described_class.default.fetch("-10")]
    it_behaves_like "a runnable default query", ["-11", described_class.default.fetch("-11")]
    it_behaves_like "a runnable default query", ["-12", described_class.default.fetch("-12")]
    it_behaves_like "a runnable default query", ["-13", described_class.default.fetch("-13")]
    it_behaves_like "a runnable default query", ["-14", described_class.default.fetch("-14")]
    it_behaves_like "a runnable default query", ["-15", described_class.default.fetch("-15")]
    it_behaves_like "a runnable default query", ["-16", described_class.default.fetch("-16")]
    it_behaves_like "a runnable default query", ["-17", described_class.default.fetch("-17")]
    it_behaves_like "a runnable default query", ["-18", described_class.default.fetch("-18")]
    it_behaves_like "a runnable default query", ["-19", described_class.default.fetch("-19")]
    it_behaves_like "a runnable default query", ["-20", described_class.default.fetch("-20")]
    it_behaves_like "a runnable default query", ["-21", described_class.default.fetch("-21")]
    it_behaves_like "a runnable default query", ["-22", described_class.default.fetch("-22")]
    it_behaves_like "a runnable default query", ["-23", described_class.default.fetch("-23")]
    it_behaves_like "a runnable default query", ["-24", described_class.default.fetch("-24")]
    it_behaves_like "a runnable default query", ["-25", described_class.default.fetch("-25")]
    it_behaves_like "a runnable default query", ["-26", described_class.default.fetch("-26")]
    it_behaves_like "a runnable default query", ["-27", described_class.default.fetch("-27")]
    it_behaves_like "a runnable default query", ["-28", described_class.default.fetch("-28")]
    it_behaves_like "a runnable default query", ["-29", described_class.default.fetch("-29")]
    it_behaves_like "a runnable default query", ["-30", described_class.default.fetch("-30")]
    it_behaves_like "a runnable default query", ["-31", described_class.default.fetch("-31")]
    it_behaves_like "a runnable default query", ["-32", described_class.default.fetch("-32")]
    it_behaves_like "a runnable default query", ["-33", described_class.default.fetch("-33")]
    it_behaves_like "a runnable default query", ["-34", described_class.default.fetch("-34")]
    it_behaves_like "a runnable default query", ["-35", described_class.default.fetch("-35")]
    it_behaves_like "a runnable default query", ["-36", described_class.default.fetch("-36")]
    it_behaves_like "a runnable default query", ["-37", described_class.default.fetch("-37")]
    it_behaves_like "a runnable default query", ["-38", described_class.default.fetch("-38")]
    it_behaves_like "a runnable default query", ["-39", described_class.default.fetch("-39")]
    it_behaves_like "a runnable default query", ["-40", described_class.default.fetch("-40")]
    it_behaves_like "a runnable default query", ["-41", described_class.default.fetch("-41")]
    it_behaves_like "a runnable default query", ["-42", described_class.default.fetch("-42")]
    it_behaves_like "a runnable default query", ["-43", described_class.default.fetch("-43")]
    it_behaves_like "a runnable default query", ["-44", described_class.default.fetch("-44")]
    it_behaves_like "a runnable default query", ["-45", described_class.default.fetch("-45")]
    it_behaves_like "a runnable default query", ["-46", described_class.default.fetch("-46")]
    it_behaves_like "a runnable default query", ["-47", described_class.default.fetch("-47")]
    it_behaves_like "a runnable default query", ["-48", described_class.default.fetch("-48")]
  end
end
