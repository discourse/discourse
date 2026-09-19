# frozen_string_literal: true

RSpec.describe AdminNotice do
  it { is_expected.to validate_presence_of(:identifier) }

  describe "#message" do
    def store_problem_translation(text)
      I18n.backend.store_translations(:en, { "dashboard" => { "problem" => { "test" => text } } })
    end

    it "interpolates the notice details into the translation" do
      store_problem_translation("Something is wrong with the %{thing}")
      notice = Fabricate(:admin_notice, identifier: "test", details: { thing: "world" })
      expect(notice.message).to eq("Something is wrong with the world")
    end

    it "expands setting markers into links that survive sanitization" do
      store_problem_translation("Configure {{setting:title}} to fix this")
      notice = Fabricate(:admin_notice, identifier: "test")
      expect(notice.message).to eq(
        "Configure #{SiteSettings::LabelFormatter.linkify(:title)} to fix this",
      )
    end
  end
end
