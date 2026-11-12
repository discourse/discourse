# frozen_string_literal: true

RSpec.describe ApplicationLayoutPreloader do
  fab!(:board, :boards_board)

  let(:guardian) { Guardian.new }
  let(:preloaded_data) do
    described_class.new(
      guardian:,
      theme_id: nil,
      theme_target: :desktop,
      login_method: nil,
    ).preloaded_data
  end
  let(:payload) { JSON.parse(preloaded_data["boards:visibility"]) }

  before { enable_current_plugin }

  describe "boards:visibility" do
    it "omits the attribute when boards are disabled" do
      SiteSetting.boards_enabled = false

      expect(preloaded_data).not_to have_key("boards:visibility")
    end

    it "returns false when there are no boards" do
      board.destroy!

      expect(payload["can_see_any_boards"]).to eq(false)
    end

    it "returns false for boards restricted to logged-in users" do
      Fabricate(
        :access_control_list,
        target: board,
        permission: "view",
        allowed_group_ids: [Group::AUTO_GROUPS[:logged_in_users]],
      )

      expect(payload["can_see_any_boards"]).to eq(false)
    end

    it "returns true when an open board grants anonymous view access" do
      Fabricate(
        :access_control_list,
        target: board,
        permission: "view",
        allowed_group_ids: [Group::AUTO_GROUPS[:anonymous_users]],
      )

      expect(payload["can_see_any_boards"]).to eq(true)
    end

    it "returns false when the only publicly visible board is archived" do
      board.update!(archived: true)
      Fabricate(
        :access_control_list,
        target: board,
        permission: "view",
        allowed_group_ids: [Group::AUTO_GROUPS[:anonymous_users]],
      )

      expect(payload["can_see_any_boards"]).to eq(false)
    end

    it "omits the entry for authenticated users" do
      preloaded_data =
        described_class.new(
          guardian: board.created_by.guardian,
          theme_id: nil,
          theme_target: :desktop,
          login_method: nil,
        ).preloaded_data

      expect(preloaded_data).not_to have_key("boards:visibility")
    end

    it "reflects ACL changes without invalidating the anonymous site cache" do
      cached_site = Site.json_for(guardian)
      expect(payload["can_see_any_boards"]).to eq(false)

      Fabricate(
        :access_control_list,
        target: board,
        permission: "view",
        allowed_group_ids: [Group::AUTO_GROUPS[:anonymous_users]],
      )

      next_page =
        described_class.new(
          guardian: Guardian.new,
          theme_id: nil,
          theme_target: :desktop,
          login_method: nil,
        ).preloaded_data

      expect(JSON.parse(next_page["site"])).to eq(JSON.parse(cached_site))
      expect(JSON.parse(next_page["boards:visibility"])["can_see_any_boards"]).to eq(true)
      expect(JSON.parse(next_page["site"])).not_to have_key("anonymous_users_can_see_any_boards")
    end
  end
end
