# frozen_string_literal: true

RSpec.describe Reports::Access do
  fab!(:admin)
  fab!(:moderator)

  describe "#initialize" do
    it "requires a guardian and a supported purpose" do
      expect { described_class.new(guardian: nil) }.to raise_error(ArgumentError)
      expect { described_class.new(guardian: admin.guardian, purpose: :edit) }.to raise_error(
        ArgumentError,
      )
    end
  end

  describe "#find" do
    before { Discourse.cache.clear }

    it "binds the report to its reader's guardian and user" do
      guardian = moderator.guardian
      access = described_class.new(guardian: guardian)

      report =
        access.find(type: "signups", options: { guardian: admin.guardian, current_user: admin })

      expect(report.guardian).to equal(guardian)
      expect(report.current_user).to eq(moderator)
    end

    it "returns reports and cached payloads for the bound reader" do
      access = described_class.new(guardian: admin.guardian)

      report = access.find(type: "signups", cache: true)
      cached = access.find(type: "signups", cache: true)

      expect(report).to be_a(Report)
      expect(cached).to eq(report.as_json)
    end

    it "keeps each reader's cached reports separate" do
      described_class.new(guardian: admin.guardian).find(type: "signups", cache: true)
      access = described_class.new(guardian: moderator.guardian)

      report = access.find(type: "signups", cache: true)

      expect(report).to be_a(Report)
      expect(report.current_user).to eq(moderator)
      expect(access.find(type: "signups", cache: true)).to eq(report.as_json)
    end

    it "applies current visibility to fresh and cached reads" do
      SiteSetting.use_legacy_pageviews = true
      access = described_class.new(guardian: moderator.guardian)
      expect(access.find(type: "page_view_anon_reqs", cache: true)).to be_a(Report)

      SiteSetting.use_legacy_pageviews = false

      expect(access.find(type: "page_view_anon_reqs")).to be_nil
      expect(access.find(type: "page_view_anon_reqs", cache: true)).to be_nil
    end

    it "limits viewing to staff and applies report visibility" do
      staff_access = described_class.new(guardian: moderator.guardian)
      user_access = described_class.new(guardian: Fabricate(:user).guardian)

      expect(staff_access.find(type: "admin_logins")).to be_nil
      expect(user_access.find(type: "signups")).to be_nil
      expect(staff_access.find(type: "missing_report")).to be_nil
    end

    it "preserves admin exports for reports hidden by site settings" do
      SiteSetting.use_legacy_pageviews = false
      access = described_class.new(guardian: admin.guardian, purpose: :export)

      report = access.find(type: "page_view_anon_reqs")

      expect(report).to be_a(Report)
      expect(report.current_user).to eq(admin)
    end

    it "uses export permissions for moderators" do
      access = described_class.new(guardian: moderator.guardian, purpose: :export)

      expect(access.find(type: "signups")).to be_a(Report)
      expect(access.find(type: "admin_logins")).to be_nil
    end

    it "bypasses cached aggregates when related items are requested" do
      access = described_class.new(guardian: admin.guardian)
      access.find(type: "signups", cache: true)

      report = access.find(type: "signups", options: { include_related_items: true }, cache: true)

      expect(report).to be_a(Report)
      expect(report.related_items[:users].map { |item| item[:user][:id] }).to contain_exactly(
        admin.id,
        moderator.id,
      )
      expect(access.find(type: "signups", cache: true)).not_to have_key(:related_items)
    end
  end
end
