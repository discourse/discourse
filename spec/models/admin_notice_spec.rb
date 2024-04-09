# frozen_string_literal: true

RSpec.describe AdminNotice do
  it { is_expected.to validate_presence_of(:identifier) }

  describe "#message" do
    let(:notice) do
      Fabricate(
        :admin_notice,
        identifier: "test",
        subject: "problem",
        priority: "high",
        details: {
          thing: "world",
        },
      )
    end

    before do
      I18n.backend.store_translations(
        :en,
        { "dashboard" => { "problem" => { "test" => "Something is wrong with the %{thing}" } } },
      )
    end

    it { expect(notice.message).to eq("Something is wrong with the world") }
  end
end
