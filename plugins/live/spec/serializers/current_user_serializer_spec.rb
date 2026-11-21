# frozen_string_literal: true

RSpec.describe CurrentUserSerializer do
  fab!(:user)

  before { SiteSetting.live_enabled = true }

  def permission
    described_class.new(user, scope: user.guardian, root: false).as_json[:live_can_send_files]
  end

  it "serializes false by default and true for permitted senders" do
    expect(permission).to eq(false)
    SiteSetting.live_file_transfer_allowed_groups = Group::AUTO_GROUPS[:logged_in_users]
    expect(permission).to eq(true)
    SiteSetting.live_enabled = false
    expect(permission).to be_nil # Plugin fields are omitted when Live is disabled.
  end
end
