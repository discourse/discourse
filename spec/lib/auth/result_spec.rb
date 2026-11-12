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

  describe "#apply_user_attributes!" do
    before { result.overrides_username = true }

    it "assigns an initial username without persisting the user or enqueueing a rename" do
      result.user = Fabricate.build(:user, username: initial_username)

      expect { result.apply_user_attributes! }.not_to change { Jobs::UpdateUsername.jobs.size }

      expect(result.user.username).to eq(new_username)
      expect(result.user).to be_new_record
    end

    it "suggests an available alternative when a new user's submitted and provider usernames are taken" do
      result.user = Fabricate.build(:user, username: user.username)
      result.username = user.username

      expect { result.apply_user_attributes! }.not_to change { Jobs::UpdateUsername.jobs.size }

      expect(result.user.username).to eq("#{user.username}1")
      expect(result.user).to be_new_record
    end

    it "renames a persisted user from the stored username when there is a pending edit" do
      user.username = "pendingusername"

      result.apply_user_attributes!

      expect(user.reload.username).to eq(new_username)
      expect(Jobs::UpdateUsername.jobs.last["args"].first).to include(
        "user_id" => user.id,
        "old_username" => initial_username,
        "new_username" => new_username,
      )
    end

    it "renames a converted staged user from the stored username" do
      user.update!(staged: true)
      user.unstage!
      user.username = "pendingusername"

      result.apply_user_attributes!

      expect(user.reload.username).to eq(new_username)
      expect(Jobs::UpdateUsername.jobs.last["args"].first).to include(
        "user_id" => user.id,
        "old_username" => initial_username,
        "new_username" => new_username,
      )
    end

    it "keeps the stored username when the provider returns it during a pending edit" do
      user.username = "pendingusername"
      result.username = initial_username

      expect { result.apply_user_attributes! }.not_to change { Jobs::UpdateUsername.jobs.size }

      expect(user.username).to eq(initial_username)
      expect(user.reload.username).to eq(initial_username)
    end
  end

  describe "#apply_associated_attributes!" do
    fab!(:user_field)

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
