# frozen_string_literal: true

RSpec.describe "Param input" do
  ALL_PARAMS_SQL = <<~SQL
    -- [params]
    -- int          :int
    -- bigint       :bigint
    -- boolean      :boolean
    -- null boolean :boolean_three
    -- string       :string
    -- date         :date
    -- time         :time
    -- datetime     :datetime
    -- double       :double
    -- string       :inet
    -- user_id      :user_id
    -- post_id      :post_id
    -- topic_id     :topic_id
    -- int_list     :int_list
    -- string_list  :string_list
    -- category_id  :category_id
    -- group_id     :group_id
    -- group_list   :group_list
    -- user_list    :mul_users
    -- int          :int_with_default = 3
    -- bigint       :bigint_with_default = 12345678912345
    -- boolean      :boolean
    -- null boolean :boolean_three_with_default = #null
    -- boolean      :boolean_with_default = true
    -- string       :string_with_default = little bunny foo foo
    -- date         :date_with_default = 14 jul 2015
    -- time         :time_with_default = 5:02 pm
    -- datetime     :datetime_with_default = 14 jul 2015 5:02 pm
    -- double       :double_with_default = 3.1415
    -- string       :inet_with_default = 127.0.0.1/8
    -- user_id      :user_id_with_default = system
    -- post_id      :post_id_with_default = http://localhost:3000/t/adsfdsfajadsdafdsds-sf-awerjkldfdwe/21/1?u=system
    -- topic_id     :topic_id_with_default = /t/-/21
    -- int_list     :int_list_with_default = 1,2,3
    -- string_list  :string_list_with_default = a,b,c
    -- category_id  :category_id_with_default = general
    -- group_id     :group_id_with_default = staff
    -- group_list   :group_list_with_default = trust_level_0,trust_level_1
    -- user_list    :mul_users_with_default = system,discobot
    SELECT 1
  SQL

  fab!(:admin)
  fab!(:all_params_query) do
    Fabricate(:query, name: "All params query", description: "", sql: ALL_PARAMS_SQL, user: admin)
  end

  let(:query_runner) { PageObjects::Pages::DataExplorerQueryRunner.new }

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in(admin)
  end

  it "correctly displays parameter input boxes" do
    visit("/admin/plugins/discourse-data-explorer/queries/#{all_params_query.id}")

    DiscourseDataExplorer::Parameter
      .create_from_sql(ALL_PARAMS_SQL)
      .each do |param|
        expect(page).to have_css(".query-params .param [name=\"#{param.identifier}\"]")

        # select-kit fields
        ignore_fields = %i[user_id post_id topic_id category_id group_id group_list user_list]

        if param.default.present? && ignore_fields.exclude?(param.type)
          expect(page).to have_field(
            param.identifier,
            with: simple_normalize(param.type, param.default),
          )
        end
      end
  end

  context "with a group_list param" do
    fab!(:q2) do
      Fabricate(
        :query,
        name: "My query with group_list",
        description: "Test group_list query",
        sql:
          "-- [params]\n-- group_list :groups\n\nSELECT g.id,g.name FROM groups g WHERE g.name IN(:groups) ORDER BY g.name ASC",
        user: admin,
      )
    end

    it "supports setting a group_list param" do
      query_runner.visit_admin_query(q2.id, params: { groups: "admins,trust_level_1" }).run_query

      expect(query_runner).to have_result_header
      expect(query_runner).to have_result_cell_at(1, 2, text: "admins")
      expect(query_runner).to have_result_cell_at(2, 2, text: "trust_level_1")
    end
  end

  context "with a current_user_id param" do
    fab!(:query) { Fabricate(:query, name: "My current user query", sql: <<~SQL, user: admin) }
      -- [params]
      -- current_user_id :me
      SELECT id, username FROM users WHERE id = :me
    SQL

    it "auto-injects the current user's id without showing an input field" do
      query_runner.visit_admin_query(query.id)

      expect(query_runner).to have_no_params
      query_runner.run_query

      expect(query_runner).to have_result_header
      expect(query_runner).to have_result_row_count(1)
      expect(query_runner).to have_result_cell(admin.username)
    end
  end

  context "with a sql query with default params" do
    fab!(:query_with_defaults) do
      Fabricate(
        :query,
        name: "Query with defaults",
        sql:
          "-- [params]\n-- int :limit = 10\n-- string :name = hello world\n\nSELECT :name AS name LIMIT :limit",
        user: admin,
      )
    end

    it "sets up the input fields with the default params" do
      query_runner.visit_admin_query(query_with_defaults.id)

      expect(page).to have_field("limit", with: "10")
      expect(page).to have_field("name", with: "hello world")
    end

    it "overrides sql params when URL params are provided" do
      query_runner.visit_admin_query(
        query_with_defaults.id,
        params: {
          limit: "25",
          name: "override",
        },
      )

      expect(page).to have_field("limit", with: "25")
      expect(page).to have_field("name", with: "override")
    end
  end
end

def simple_normalize(type, value)
  case type
  when :date
    value.to_date.to_s
  when :time
    value.to_time.strftime("%H:%M")
  when :datetime
    value.to_datetime.strftime("%Y-%m-%dT%H:%M")
  when :boolean
    value == "#null" ? "#null" : value ? "on" : "off"
  when :boolean_three
    value == "#null" ? "#null" : value ? "Y" : "N"
  else
    value.to_s
  end
end
