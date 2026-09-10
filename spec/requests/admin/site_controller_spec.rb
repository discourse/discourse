# frozen_string_literal: true

RSpec.describe Admin::SiteController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  after { Discourse.disable_readonly_mode(Discourse::ARCHIVE_MODE_KEY) }

  describe "#archive" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "enables archive mode" do
        expect(Discourse.archive_mode?).to eq(false)

        expect { put "/admin/site/archive.json", params: { enable: true } }.to change {
          UserHistory.where(action: UserHistory.actions[:change_archive_mode], new_value: "t").count
        }.by(1)

        expect(response.status).to eq(200)
        expect(Discourse.archive_mode?).to eq(true)
        expect(Discourse.readonly_mode?).to eq(true)
      end

      it "disables archive mode" do
        Discourse.enable_readonly_mode(Discourse::ARCHIVE_MODE_KEY)
        expect(Discourse.archive_mode?).to eq(true)

        expect { put "/admin/site/archive.json", params: { enable: false } }.to change {
          UserHistory.where(action: UserHistory.actions[:change_archive_mode], new_value: "f").count
        }.by(1)

        expect(response.status).to eq(200)
        expect(Discourse.archive_mode?).to eq(false)
      end

      it "works even when the site is already in archive mode" do
        Discourse.enable_readonly_mode(Discourse::ARCHIVE_MODE_KEY)
        put "/admin/site/archive.json", params: { enable: false }
        expect(response.status).to eq(200)
      end
    end

    shared_examples "toggling archive mode not allowed" do
      it "returns 404" do
        expect do put "/admin/site/archive.json", params: { enable: true } end.not_to change {
          UserHistory.where(action: UserHistory.actions[:change_archive_mode]).count
        }

        expect(response.status).to eq(404)
        expect(Discourse.archive_mode?).to eq(false)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "toggling archive mode not allowed"
    end

    context "when logged in as a regular user" do
      before { sign_in(user) }

      include_examples "toggling archive mode not allowed"
    end

    context "when not logged in" do
      include_examples "toggling archive mode not allowed"
    end
  end
end
