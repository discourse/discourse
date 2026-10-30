# frozen_string_literal: true

describe DiscourseDataExplorer::Queries do
  fab!(:user)
  fab!(:post)
  fab!(:group)

  before { SiteSetting.data_explorer_enabled = true }

  describe ".default" do
    shared_examples "a runnable default query" do |id:, attributes:|
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

    it_behaves_like "a runnable default query",
                    id: "-1",
                    attributes: described_class.default.fetch("-1")
    it_behaves_like "a runnable default query",
                    id: "-2",
                    attributes: described_class.default.fetch("-2")
    it_behaves_like "a runnable default query",
                    id: "-3",
                    attributes: described_class.default.fetch("-3")
    it_behaves_like "a runnable default query",
                    id: "-4",
                    attributes: described_class.default.fetch("-4")
    it_behaves_like "a runnable default query",
                    id: "-5",
                    attributes: described_class.default.fetch("-5")
    it_behaves_like "a runnable default query",
                    id: "-6",
                    attributes: described_class.default.fetch("-6")
    it_behaves_like "a runnable default query",
                    id: "-7",
                    attributes: described_class.default.fetch("-7")
    it_behaves_like "a runnable default query",
                    id: "-8",
                    attributes: described_class.default.fetch("-8")
    it_behaves_like "a runnable default query",
                    id: "-9",
                    attributes: described_class.default.fetch("-9")
    it_behaves_like "a runnable default query",
                    id: "-10",
                    attributes: described_class.default.fetch("-10")
    it_behaves_like "a runnable default query",
                    id: "-11",
                    attributes: described_class.default.fetch("-11")
    it_behaves_like "a runnable default query",
                    id: "-12",
                    attributes: described_class.default.fetch("-12")
    it_behaves_like "a runnable default query",
                    id: "-13",
                    attributes: described_class.default.fetch("-13")
    it_behaves_like "a runnable default query",
                    id: "-14",
                    attributes: described_class.default.fetch("-14")
    it_behaves_like "a runnable default query",
                    id: "-15",
                    attributes: described_class.default.fetch("-15")
    it_behaves_like "a runnable default query",
                    id: "-16",
                    attributes: described_class.default.fetch("-16")
    it_behaves_like "a runnable default query",
                    id: "-17",
                    attributes: described_class.default.fetch("-17")
    it_behaves_like "a runnable default query",
                    id: "-18",
                    attributes: described_class.default.fetch("-18")
    it_behaves_like "a runnable default query",
                    id: "-19",
                    attributes: described_class.default.fetch("-19")
    it_behaves_like "a runnable default query",
                    id: "-20",
                    attributes: described_class.default.fetch("-20")
    it_behaves_like "a runnable default query",
                    id: "-21",
                    attributes: described_class.default.fetch("-21")
    it_behaves_like "a runnable default query",
                    id: "-22",
                    attributes: described_class.default.fetch("-22")
    it_behaves_like "a runnable default query",
                    id: "-23",
                    attributes: described_class.default.fetch("-23")
    it_behaves_like "a runnable default query",
                    id: "-24",
                    attributes: described_class.default.fetch("-24")
    it_behaves_like "a runnable default query",
                    id: "-25",
                    attributes: described_class.default.fetch("-25")
    it_behaves_like "a runnable default query",
                    id: "-26",
                    attributes: described_class.default.fetch("-26")
    it_behaves_like "a runnable default query",
                    id: "-27",
                    attributes: described_class.default.fetch("-27")
    it_behaves_like "a runnable default query",
                    id: "-28",
                    attributes: described_class.default.fetch("-28")
    it_behaves_like "a runnable default query",
                    id: "-29",
                    attributes: described_class.default.fetch("-29")
    it_behaves_like "a runnable default query",
                    id: "-30",
                    attributes: described_class.default.fetch("-30")
    it_behaves_like "a runnable default query",
                    id: "-31",
                    attributes: described_class.default.fetch("-31")
    it_behaves_like "a runnable default query",
                    id: "-32",
                    attributes: described_class.default.fetch("-32")
    it_behaves_like "a runnable default query",
                    id: "-33",
                    attributes: described_class.default.fetch("-33")
    it_behaves_like "a runnable default query",
                    id: "-34",
                    attributes: described_class.default.fetch("-34")
    it_behaves_like "a runnable default query",
                    id: "-35",
                    attributes: described_class.default.fetch("-35")
    it_behaves_like "a runnable default query",
                    id: "-36",
                    attributes: described_class.default.fetch("-36")
    it_behaves_like "a runnable default query",
                    id: "-37",
                    attributes: described_class.default.fetch("-37")
    it_behaves_like "a runnable default query",
                    id: "-38",
                    attributes: described_class.default.fetch("-38")
    it_behaves_like "a runnable default query",
                    id: "-39",
                    attributes: described_class.default.fetch("-39")
    it_behaves_like "a runnable default query",
                    id: "-40",
                    attributes: described_class.default.fetch("-40")
    it_behaves_like "a runnable default query",
                    id: "-41",
                    attributes: described_class.default.fetch("-41")
    it_behaves_like "a runnable default query",
                    id: "-42",
                    attributes: described_class.default.fetch("-42")
    it_behaves_like "a runnable default query",
                    id: "-43",
                    attributes: described_class.default.fetch("-43")
    it_behaves_like "a runnable default query",
                    id: "-44",
                    attributes: described_class.default.fetch("-44")
    it_behaves_like "a runnable default query",
                    id: "-45",
                    attributes: described_class.default.fetch("-45")
    it_behaves_like "a runnable default query",
                    id: "-46",
                    attributes: described_class.default.fetch("-46")
    it_behaves_like "a runnable default query",
                    id: "-47",
                    attributes: described_class.default.fetch("-47")
    it_behaves_like "a runnable default query",
                    id: "-48",
                    attributes: described_class.default.fetch("-48")
  end
end
