# frozen_string_literal: true

RSpec.describe UserSerializer do
  fab!(:current_user) { Fabricate(:user) }

  let(:serializer) do
    described_class.new(current_user, scope: Guardian.new(current_user), root: false)
  end

  describe "#chat_separate_sidebar_mode" do
    it "is present" do
      expect(serializer.as_json[:user_option][:chat_separate_sidebar_mode]).to eq("default")
    end
  end
end
