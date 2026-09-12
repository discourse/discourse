# frozen_string_literal: true
RSpec.describe Auth::Result do
  fab!(:initial_email) { "initialemail@example.org" }
  fab!(:initial_username) { "initialusername" }
  fab!(:initial_name) { "Initial Name" }
  fab!(:user) do
    Fabricate(:user, email: initial_email, username: initial_username, name: initial_name)
  end

  let(:new_email) { "newemail@example.org" }
  let(:new_username) { "newusername" }
  let(:new_name) { "New Name" }

  let(:result) do
    result = Auth::Result.new
    result.email = new_email
    result.username = new_username
    result.name = new_name
    result.user = user
    result.email_valid = true
    result
  end

  it "doesn't override user attributes by default" do
    result.apply_user_attributes!
    expect(user.email).to eq(initial_email)
    expect(user.username).to eq(initial_username)
    expect(user.name).to eq(initial_name)
  end

  it "overrides user attributes when site settings enabled" do
    SiteSetting.email_editable = false
    SiteSetting.auth_overrides_email = true
    SiteSetting.auth_overrides_name = true
    SiteSetting.auth_overrides_username = true

    result.apply_user_attributes!

    expect(user.email).to eq(new_email)
    expect(user.username).to eq(new_username)
    expect(user.name).to eq(new_name)
  end

  it "overrides user attributes when result attributes set" do
    result.overrides_email = true
    result.overrides_name = true
    result.overrides_username = true

    result.apply_user_attributes!

    expect(user.email).to eq(new_email)
    expect(user.username).to eq(new_username)
    expect(user.name).to eq(new_name)
  end

  it "overrides username with suggested value if missing" do
    SiteSetting.auth_overrides_username = true

    result.username = nil
    result.apply_user_attributes!

    expect(user.username).to eq("New_Name")
  end

  it "updates the user's email if currently invalid" do
    user.update!(email: "someemail@discourse.org")
    expect { result.apply_user_attributes! }.not_to change { user.email }

    user.update!(email: "someemail@discourse.invalid")
    expect { result.apply_user_attributes! }.to change { user.email }

    expect(user.email).to eq(new_email)
  end

  describe "#apply_associated_attributes!" do
    fab!(:user_field)
    fab!(:existing_associated_group) do
      AssociatedGroup.create!(
        name: "Existing group",
        provider_id: "existing-group",
        provider_name: "test",
      )
    end

    before { result.extra_data = { provider: "test" } }

    it "does not manage associated groups when they are unset" do
      user.update!(associated_group_ids: [existing_associated_group.id])

      result.associated_groups = nil
      result.apply_associated_attributes!

      expect(user.reload.associated_group_ids).to eq([existing_associated_group.id])
    end

    it "clears associated groups when they are set to an empty array" do
      user.update!(associated_group_ids: [existing_associated_group.id])

      result.associated_groups = []
      result.apply_associated_attributes!

      expect(user.reload.associated_groups).to be_empty
    end

    it "persists associated groups when provided by the result" do
      result.associated_groups = [{ id: "engineering", name: "Engineering" }]
      result.apply_associated_attributes!

      associated_group = AssociatedGroup.find_by(provider_id: "engineering")

      expect(associated_group.name).to eq("Engineering")
      expect(user.reload.associated_groups).to contain_exactly(associated_group)
    end

    it "writes user_field_values to the user's custom fields" do
      result.user_field_values = { user_field.id.to_s => "Engineering" }
      result.apply_associated_attributes!

      expect(user.reload.custom_fields["user_field_#{user_field.id}"]).to eq("Engineering")
    end

    it "is a no-op when user_field_values is blank" do
      result.user_field_values = nil
      expect { result.apply_associated_attributes! }.not_to raise_error
    end

    it "round-trips user_field_values through session data" do
      result.user_field_values = { "42" => "Engineering" }
      restored = Auth::Result.from_session_data(result.session_data, user: user)

      expect(restored.user_field_values).to eq("42" => "Engineering")
    end
  end
end
