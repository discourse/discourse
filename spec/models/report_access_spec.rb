# frozen_string_literal: true

RSpec.describe Report do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  before { Discourse.cache.clear }

  %i[find find_cached].each do |method|
    describe ".#{method}" do
      it "requires an explicit guardian" do
        expect { described_class.public_send(method, "signups") }.to raise_error(ArgumentError)
        expect { described_class.public_send(method, "signups", guardian: nil) }.to raise_error(
          ArgumentError,
          "guardian is required",
        )
      end

      it "rejects unsupported purposes" do
        expect {
          described_class.public_send(method, "signups", guardian: admin.guardian, purpose: :edit)
        }.to raise_error(ArgumentError, "invalid report purpose")
      end

      it "denies viewing reports to regular and anonymous users" do
        expect(described_class.public_send(method, "signups", guardian: user.guardian)).to be_nil
        expect(described_class.public_send(method, "signups", guardian: Guardian.new)).to be_nil
      end

      it "denies admin-only reports to moderators" do
        expect(
          described_class.public_send(method, "admin_logins", guardian: moderator.guardian),
        ).to be_nil
      end

      it "denies exporting reports to regular users" do
        expect(
          described_class.public_send(method, "signups", guardian: user.guardian, purpose: :export),
        ).to be_nil
      end
    end
  end

  describe ".find" do
    it "derives the report's actor from its guardian" do
      guardian = moderator.guardian

      report = described_class.find("signups", guardian: guardian, current_user: admin)

      expect(report.guardian).to equal(guardian)
      expect(report.current_user).to eq(moderator)
    end

    it "returns nil for unknown reports" do
      expect(described_class.find("missing_report", guardian: admin.guardian)).to be_nil
    end

    it "preserves admin exports for reports hidden by site settings" do
      SiteSetting.use_legacy_pageviews = false

      report =
        described_class.find("page_view_anon_reqs", guardian: admin.guardian, purpose: :export)

      expect(report).to be_a(Report)
      expect(report.current_user).to eq(admin)
      expect(described_class.find("page_view_anon_reqs", guardian: admin.guardian)).to be_nil
    end

    it "uses export permissions for moderators" do
      expect(
        described_class.find("signups", guardian: moderator.guardian, purpose: :export),
      ).to be_a(Report)
      expect(
        described_class.find("admin_logins", guardian: moderator.guardian, purpose: :export),
      ).to be_nil
    end

    it "includes related crawler reports when viewing crawler requests" do
      report = described_class.find("page_view_crawler_reqs", guardian: moderator.guardian)

      expect(report.as_json[:related_report][:type]).to eq("web_crawlers")
    end

    it "applies export permissions when serializing related crawler reports" do
      guardian = admin.guardian
      guardian.stubs(:can_export_entity?).returns(true)
      guardian.stubs(:can_export_entity?).with("report", nil, name: "web_crawlers").returns(false)

      report = described_class.find("page_view_crawler_reqs", guardian: guardian, purpose: :export)

      expect(report.as_json[:related_report]).to be_nil
    end
  end

  describe ".find_cached" do
    it "returns the cached payload for its reader" do
      report = described_class.find("signups", guardian: admin.guardian)
      described_class.cache(report)

      expect(described_class.find_cached("signups", guardian: admin.guardian)).to eq(report.as_json)
    end

    it "keeps each reader's cached reports separate" do
      report = described_class.find("signups", guardian: admin.guardian)
      described_class.cache(report)

      expect(described_class.find_cached("signups", guardian: moderator.guardian)).to be_nil
    end

    it "applies current visibility to fresh and cached reads" do
      SiteSetting.use_legacy_pageviews = true
      report = described_class.find("page_view_anon_reqs", guardian: moderator.guardian)
      described_class.cache(report)
      expect(
        described_class.find_cached("page_view_anon_reqs", guardian: moderator.guardian),
      ).to be_present

      SiteSetting.use_legacy_pageviews = false

      expect(described_class.find("page_view_anon_reqs", guardian: moderator.guardian)).to be_nil
      expect(
        described_class.find_cached("page_view_anon_reqs", guardian: moderator.guardian),
      ).to be_nil
    end

    it "keeps view and export payloads separate" do
      report = described_class.find("signups", guardian: admin.guardian, purpose: :export)
      described_class.cache(report)

      expect(described_class.find_cached("signups", guardian: admin.guardian)).to be_nil
      expect(
        described_class.find_cached("signups", guardian: admin.guardian, purpose: :export),
      ).to eq(report.as_json)
    end

    it "applies export permissions to cached reports" do
      report = described_class.find("signups", guardian: moderator.guardian, purpose: :export)
      described_class.cache(report)
      moderator.update!(moderator: false)

      expect(
        described_class.find_cached("signups", guardian: moderator.guardian, purpose: :export),
      ).to be_nil
    end

    it "bypasses cached aggregates when related items are requested" do
      report = described_class.find("signups", guardian: admin.guardian)
      described_class.cache(report)

      expect(
        described_class.find_cached(
          "signups",
          guardian: admin.guardian,
          include_related_items: true,
        ),
      ).to be_nil
      expect(described_class.find_cached("signups", guardian: admin.guardian)).to eq(report.as_json)
    end
  end
end
