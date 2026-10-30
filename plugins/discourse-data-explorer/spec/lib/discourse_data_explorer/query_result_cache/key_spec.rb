# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::QueryResultCache::Key do
  let(:identity) { described_class.for(-1, Discourse.system_user, {}) }

  before { SiteSetting.suppress_secured_categories_from_admin = true }

  describe ".parse" do
    subject(:parsed_identity) { described_class.parse(identity.id) }

    it "round-trips negative query and user identifiers" do
      expect(parsed_identity).to eq(identity)
    end
  end
end
