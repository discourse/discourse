# frozen_string_literal: true

describe UsersController do
  fab!(:user)

  before { enable_current_plugin }

  describe "#update" do
    before { sign_in(user) }

    it "persists the Discoveries summary detail preference" do
      put "/u/#{user.username}.json", params: { ai_search_discoveries_summary_detail: 2 }

      expect(response.status).to eq(200)
      expect(user.user_option.reload.ai_search_discoveries_summary_detail).to eq(2)
    end
  end
end
