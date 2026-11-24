# frozen_string_literal: true

# A migrating select family keeps flag-off specs for its legacy branch until that branch is
# deleted, and adds flag-on specs for its new one. Each must keep its mode whatever the change's
# status.
RSpec.describe "Pinning enable_new_select_controls in specs" do
  def client_value
    JSON.parse(SiteSetting.client_settings_json)["enable_new_select_controls"]
  end

  context "when the change is not promoted" do
    it "is off without a pin" do
      expect(SiteSetting.enable_new_select_controls).to eq(false)
    end

    context "when pinned on" do
      with_select_controls(true)

      it "is on, on the server and in the client settings" do
        expect(SiteSetting.enable_new_select_controls).to eq(true)
        expect(client_value).to eq(true)
      end
    end
  end

  context "when the change is promoted" do
    before do
      mock_upcoming_change_metadata(
        enable_new_select_controls:
          SiteSetting.upcoming_change_metadata[:enable_new_select_controls].merge(status: :stable),
      )
      SiteSetting.promote_upcoming_changes_on_status = "beta"
    end

    it "is on without a pin" do
      expect(SiteSetting.enable_new_select_controls).to eq(true)
      expect(client_value).to eq(true)
    end

    context "when pinned off" do
      with_select_controls(false)

      it "stays off, on the server and in the client settings" do
        expect(SiteSetting.enable_new_select_controls).to eq(false)
        expect(client_value).to eq(false)
      end
    end
  end
end
