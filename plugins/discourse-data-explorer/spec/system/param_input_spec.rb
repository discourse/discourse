# frozen_string_literal: true

RSpec.describe "Param input", type: :system do
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

  fab!(:current_user, :admin)
  fab!(:all_params_query) do
    Fabricate(
      :query,
      name: "All params query",
      description: "",
      sql: ALL_PARAMS_SQL,
      user: current_user,
    )
  end

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in(current_user)
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
