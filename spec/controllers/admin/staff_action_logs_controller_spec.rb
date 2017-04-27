require 'rails_helper'

describe Admin::StaffActionLogsController do
  it "is a subclass of AdminController" do
    expect(Admin::StaffActionLogsController < Admin::AdminController).to eq(true)
  end

  let!(:user) { log_in(:admin) }

  context '.index' do

    it 'works' do
      xhr :get, :index
      expect(response).to be_success
      expect(::JSON.parse(response.body)).to be_a(Array)
    end
  end

  context '.diff' do
    it 'can generate diffs for theme changes' do
      theme = Theme.new(user_id: -1, name: 'bob')
      theme.set_field(:mobile, :scss, 'body {.up}')
      theme.set_field(:common, :scss, 'omit-dupe')

      original_json = ThemeSerializer.new(theme, root: false).to_json

      theme.set_field(:mobile, :scss, 'body {.down}')

      record = StaffActionLogger.new(Discourse.system_user)
        .log_theme_change(original_json, theme)

      xhr :get, :diff, id: record.id
      expect(response).to be_success

      parsed = JSON.parse(response.body)
      expect(parsed["side_by_side"]).to include("up")
      expect(parsed["side_by_side"]).to include("down")

      expect(parsed["side_by_side"]).not_to include("omit-dupe")
    end
  end
end
