# frozen_string_literal: true

describe "Add user to group through custom field", type: :request do
  fab!(:automation) { Fabricate(:automation, script: "add_user_to_group_through_custom_field") }

  fab!(:dropdown_field) do
    Fabricate(:user_field, field_type: "dropdown", requirement: "optional").tap do |field|
      field.user_field_options.create!(value: "Engineering")
      field.user_field_options.create!(value: "Sales")
    end
  end

  fab!(:staff_group) { Group.find_by(name: "staff") }

  fab!(:staff_only_category) do
    Fabricate(:category, name: "Staff Only", read_restricted: true).tap do |category|
      category.set_permissions(staff_group => :full)
      category.save!
    end
  end

  fab!(:staff_only_topic) { Fabricate(:topic, category: staff_only_category) }

  before do
    SiteSetting.discourse_automation_enabled = true
    SiteSetting.enable_local_logins_via_code = true

    automation.upsert_field!(
      "custom_field_name",
      "custom_field",
      { value: dropdown_field.id },
      target: "script",
    )
  end

  def signup_with_field_value(value)
    login_code = EmailLoginCode.generate!(email: "attacker@example.com")

    post "/session/login-code/verify.json",
         params: {
           email: "attacker@example.com",
           code: login_code.code,
           user_fields: {
             dropdown_field.id.to_s => value,
           },
         }

    User.find_by_email("attacker@example.com")
  end

  it "does not let a signup pick a value outside the field's options to join the staff group" do
    get "/t/#{staff_only_topic.slug}/#{staff_only_topic.id}.json"
    expect(response.status).to eq(404)

    user = signup_with_field_value("Staff")

    expect(user).to be_present
    expect(user.user_fields[dropdown_field.id.to_s]).to be_nil

    automation.trigger!("kind" => DiscourseAutomation::Triggers::RECURRING)

    expect(user.reload.in_any_groups?([staff_group.id])).to eq(false)

    get "/t/#{staff_only_topic.slug}/#{staff_only_topic.id}.json"
    expect(response.status).to eq(404)
  end

  it "still maps a configured option to a group" do
    target_group = Fabricate(:group, full_name: "Engineering")

    user = signup_with_field_value("Engineering")

    expect(user.user_fields[dropdown_field.id.to_s]).to eq("Engineering")

    automation.trigger!("kind" => DiscourseAutomation::Triggers::RECURRING)

    expect(user.reload.in_any_groups?([target_group.id])).to eq(true)
  end
end
