# frozen_string_literal: true

require_relative "../../dummy_provider"

RSpec.describe ProblemCheck::ChannelErrors do
  include_context "with dummy provider"

  let(:check) { described_class.new }

  context "when chat integration is not enabled" do
    before { SiteSetting.stubs(chat_integration_enabled: false) }

    it { expect(check).to be_chill_about_it }
  end

  context "when chat integration is enabled" do
    before { SiteSetting.stubs(chat_integration_enabled: true) }

    context "when an enabled channel has errors" do
      before { Fabricate(:channel, provider: "dummy", error_key: "whoops") }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          "Some chat integration channels have errors. Visit <a href='/admin/plugins/chat-integration'>the chat integration section</a> to find out more.",
        )
      end
    end

    context "when a disabled chanel has errors" do
      before { Fabricate(:channel, provider: "dummy", error_key: nil) }

      it { expect(check).to be_chill_about_it }
    end
  end
end
