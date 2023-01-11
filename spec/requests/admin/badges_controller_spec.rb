# frozen_string_literal: true

RSpec.describe Admin::BadgesController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:user) { Fabricate(:user, email: "user1@test.com", username: "username1") }
  fab!(:badge) { Fabricate(:badge) }

  describe "#index" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns badge index" do
        get "/admin/badges.json"
        expect(response.status).to eq(200)
      end
    end

    shared_examples "badges inaccessible" do
      it "denies access to badges with a 404 response" do
        get "/admin/badges.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "badges inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "badges inaccessible"
    end
  end

  describe "#preview" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "allows preview enable_badge_sql is enabled" do
        SiteSetting.enable_badge_sql = true

        post "/admin/badges/preview.json",
             params: {
               sql: "select id as user_id, created_at granted_at from users",
             }

        expect(response.status).to eq(200)
        expect(response.parsed_body["grant_count"]).to be > 0
      end

      it "does not allow anything if enable_badge_sql is disabled" do
        SiteSetting.enable_badge_sql = false

        post "/admin/badges/preview.json",
             params: {
               sql: "select id as user_id, created_at granted_at from users",
             }

        expect(response.status).to eq(403)
      end
    end

    shared_examples "badge preview inaccessible" do
      it "denies access to badge preview with a 404 response" do
        SiteSetting.enable_badge_sql = true

        post "/admin/badges/preview.json",
             params: {
               sql: "select id as user_id, created_at granted_at from users",
             }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "badge preview inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "badge preview inaccessible"
    end
  end

  describe "#create" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "can create badges correctly" do
        SiteSetting.enable_badge_sql = true

        post "/admin/badges.json",
             params: {
               name: "test",
               query: "select 1 as user_id, null as granted_at",
               badge_type_id: 1,
             }

        json = response.parsed_body
        expect(response.status).to eq(200)
        expect(json["badge"]["name"]).to eq("test")
        expect(json["badge"]["query"]).to eq("select 1 as user_id, null as granted_at")

        expect(
          UserHistory.where(
            acting_user_id: admin.id,
            action: UserHistory.actions[:create_badge],
          ).exists?,
        ).to eq(true)
      end
    end

    shared_examples "badge creation not allowed" do
      it "prevents badge creation with a 404 response" do
        SiteSetting.enable_badge_sql = true

        post "/admin/badges.json",
             params: {
               name: "test",
               query: "select 1 as user_id, null as granted_at",
               badge_type_id: 1,
             }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "badge creation not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "badge creation not allowed"
    end
  end

  describe "#save_badge_groupings" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "can save badge groupings" do
        groupings = BadgeGrouping.all.order(:position).to_a
        groupings << BadgeGrouping.new(name: "Test 1")
        groupings << BadgeGrouping.new(name: "Test 2")

        groupings.shuffle!

        names = groupings.map { |g| g.name }
        ids = groupings.map { |g| g.id.to_s }

        post "/admin/badges/badge_groupings.json", params: { ids: ids, names: names }
        expect(response.status).to eq(200)

        groupings2 = BadgeGrouping.all.order(:position).to_a

        expect(groupings2.map { |g| g.name }).to eq(names)
        expect((groupings.map(&:id) - groupings2.map { |g| g.id }).compact).to be_blank
        expect(response.parsed_body["badge_groupings"].length).to eq(groupings2.length)
      end
    end

    shared_examples "badge grouping creation not allowed" do
      it "prevents creation of badge groupings with a 404 response" do
        groupings = BadgeGrouping.all.order(:position).to_a
        groupings << BadgeGrouping.new(name: "Test 1")
        groupings << BadgeGrouping.new(name: "Test 2")

        groupings.shuffle!

        names = groupings.map { |g| g.name }
        ids = groupings.map { |g| g.id.to_s }

        post "/admin/badges/badge_groupings.json", params: { ids: ids, names: names }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "badge grouping creation not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "badge grouping creation not allowed"
    end
  end

  describe "#badge_types" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns JSON" do
        get "/admin/badges/types.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["badge_types"]).to be_present
      end
    end

    shared_examples "badge types inaccessible" do
      it "denies access to badge types with a 404 response" do
        get "/admin/badges/types.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "badge types inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "badge types inaccessible"
    end
  end

  describe "#destroy" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "deletes the badge" do
        delete "/admin/badges/#{badge.id}.json"
        expect(response.status).to eq(200)
        expect(Badge.where(id: badge.id).exists?).to eq(false)
        expect(
          UserHistory.where(
            acting_user_id: admin.id,
            action: UserHistory.actions[:delete_badge],
          ).exists?,
        ).to eq(true)
      end
    end

    shared_examples "badge deletion not allowed" do
      it "prevents deletion of badges with a 404 response" do
        delete "/admin/badges/#{badge.id}.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(Badge.where(id: badge.id).exists?).to eq(true)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "badge deletion not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "badge deletion not allowed"
    end
  end

  describe "#update" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "does not update the name of system badges" do
        editor_badge = Badge.find(Badge::Editor)
        editor_badge_name = editor_badge.name

        put "/admin/badges/#{editor_badge.id}.json", params: { name: "123456" }

        expect(response.status).to eq(200)
        editor_badge.reload
        expect(editor_badge.name).to eq(editor_badge_name)

        expect(
          UserHistory.where(
            acting_user_id: admin.id,
            action: UserHistory.actions[:change_badge],
          ).exists?,
        ).to eq(true)
      end

      it "does not allow query updates if badge_sql is disabled" do
        badge.query = "select 123"
        badge.save

        SiteSetting.enable_badge_sql = false

        put "/admin/badges/#{badge.id}.json",
            params: {
              name: "123456",
              query: "select id user_id, created_at granted_at from users",
              badge_type_id: badge.badge_type_id,
              allow_title: false,
              multiple_grant: false,
              enabled: true,
            }

        expect(response.status).to eq(200)
        badge.reload
        expect(badge.name).to eq("123456")
        expect(badge.query).to eq("select 123")
      end

      it "updates the badge" do
        SiteSetting.enable_badge_sql = true
        sql = "select id user_id, created_at granted_at from users"
        image = Fabricate(:upload)

        put "/admin/badges/#{badge.id}.json",
            params: {
              name: "123456",
              query: sql,
              badge_type_id: badge.badge_type_id,
              allow_title: false,
              multiple_grant: false,
              enabled: true,
              image_upload_id: image.id,
              icon: "fa-rocket",
            }

        expect(response.status).to eq(200)
        badge.reload
        expect(badge.name).to eq("123456")
        expect(badge.query).to eq(sql)
        expect(badge.image_upload.id).to eq(image.id)
        expect(badge.icon).to eq("fa-rocket")
      end

      context "when there is a user with a title granted using the badge" do
        fab!(:user_with_badge_title) { Fabricate(:active_user) }
        fab!(:badge) { Fabricate(:badge, name: "Oathbreaker", allow_title: true) }

        before do
          BadgeGranter.grant(badge, user_with_badge_title)
          user_with_badge_title.update(title: "Oathbreaker")
        end

        it "updates the user title in a job" do
          expect_enqueued_with(
            job: :bulk_user_title_update,
            args: {
              new_title: "Shieldbearer",
              granted_badge_id: badge.id,
              action: Jobs::BulkUserTitleUpdate::UPDATE_ACTION,
            },
          ) { put "/admin/badges/#{badge.id}.json", params: { name: "Shieldbearer" } }
        end
      end
    end

    shared_examples "badge update not allowed" do
      it "prevents badge update with a 404 response" do
        SiteSetting.enable_badge_sql = true

        sql = "select id user_id, created_at granted_at from users"
        image = Fabricate(:upload)

        put "/admin/badges/#{badge.id}.json",
            params: {
              name: "123456",
              query: sql,
              badge_type_id: badge.badge_type_id,
              allow_title: false,
              multiple_grant: false,
              enabled: true,
              image_upload_id: image.id,
              icon: "fa-rocket",
            }

        badge.reload
        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(badge.name).not_to eq("123456")
        expect(badge.query).not_to eq(sql)
        expect(badge.icon).not_to eq("fa-rocket")
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "badge update not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "badge update not allowed"
    end
  end

  describe "#mass_award" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "does nothing when there is no file" do
        post "/admin/badges/award/#{badge.id}.json", params: { file: "" }

        expect(response.status).to eq(400)
      end

      it "does nothing when the badge id is not valid" do
        post "/admin/badges/award/fake_id.json", params: { file: fixture_file_upload(Tempfile.new) }

        expect(response.status).to eq(400)
      end

      it "does nothing when the file is not a csv" do
        file = file_from_fixtures("cropped.png")

        post "/admin/badges/award/#{badge.id}.json", params: { file: fixture_file_upload(file) }

        expect(response.status).to eq(400)
      end

      it "awards the badge using a list of user emails" do
        Jobs.run_immediately!

        file = file_from_fixtures("user_emails.csv", "csv")

        UserBadge.destroy_all
        post "/admin/badges/award/#{badge.id}.json", params: { file: fixture_file_upload(file) }

        expect(response.status).to eq(200)
        expect(UserBadge.where(user: user, badge: badge).count).to eq(1)
        expect(UserBadge.where(user: user, badge: badge).first.seq).to eq(0)
      end

      it "awards the badge using a list of usernames" do
        Jobs.run_immediately!

        file = file_from_fixtures("usernames.csv", "csv")

        post "/admin/badges/award/#{badge.id}.json", params: { file: fixture_file_upload(file) }

        expect(response.status).to eq(200)
        expect(UserBadge.where(user: user, badge: badge).count).to eq(1)
      end

      it "works with a CSV containing nil values" do
        Jobs.run_immediately!

        file = file_from_fixtures("usernames_with_nil_values.csv", "csv")

        post "/admin/badges/award/#{badge.id}.json", params: { file: fixture_file_upload(file) }

        expect(response.status).to eq(200)
        expect(UserBadge.where(user: user, badge: badge).count).to eq(1)
      end

      it "does not grant the badge again to a user if they already have the badge" do
        Jobs.run_immediately!
        badge.update!(multiple_grant: true)
        BadgeGranter.grant(badge, user)
        user.reload

        file = file_from_fixtures("usernames_with_nil_values.csv", "csv")

        post "/admin/badges/award/#{badge.id}.json", params: { file: fixture_file_upload(file) }

        expect(response.status).to eq(200)
        expect(UserBadge.where(user: user, badge: badge).count).to eq(1)
      end

      it "fails when the badge is disabled" do
        badge.update!(enabled: false)

        file = file_from_fixtures("usernames_with_nil_values.csv", "csv")

        post "/admin/badges/award/#{badge.id}.json", params: { file: fixture_file_upload(file) }

        expect(response.status).to eq(422)
      end

      context "when grant_existing_holders is true" do
        it "fails when the badge cannot be granted multiple times" do
          file = file_from_fixtures("user_emails.csv", "csv")
          badge.update!(multiple_grant: false)
          post "/admin/badges/award/#{badge.id}.json",
               params: {
                 file: fixture_file_upload(file),
                 grant_existing_holders: true,
               }

          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to eq(
            [I18n.t("badges.mass_award.errors.cant_grant_multiple_times", badge_name: badge.name)],
          )
        end

        it "fails when CSV file contains more entries that it's allowed" do
          badge.update!(multiple_grant: true)
          csv = Tempfile.new
          csv.write("#{user.username}\n" * 11)
          csv.rewind
          stub_const(Admin::BadgesController, "MAX_CSV_LINES", 10) do
            post "/admin/badges/award/#{badge.id}.json",
                 params: {
                   file: fixture_file_upload(csv),
                   grant_existing_holders: true,
                 }
          end
          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"]).to include(
            I18n.t("badges.mass_award.errors.too_many_csv_entries", count: 10),
          )
        ensure
          csv&.close
          csv&.unlink
        end

        it "includes unmatched entries and the number of users who will receive the badge in the response" do
          Jobs.run_immediately!
          badge.update!(multiple_grant: true)
          csv = Tempfile.new
          content = %w[nonexistentuser nonexistentuser nonexistentemail@discourse.fake]
          content << user.username
          content << user.username
          csv.write(content.join("\n"))
          csv.rewind
          post "/admin/badges/award/#{badge.id}.json",
               params: {
                 file: fixture_file_upload(csv),
                 grant_existing_holders: true,
               }
          expect(response.status).to eq(200)
          expect(response.parsed_body["unmatched_entries"]).to contain_exactly(
            "nonexistentuser",
            "nonexistentemail@discourse.fake",
          )
          expect(response.parsed_body["matched_users_count"]).to eq(1)
          expect(response.parsed_body["unmatched_entries_count"]).to eq(2)
          expect(UserBadge.where(user: user, badge: badge).count).to eq(2)
        ensure
          csv&.close
          csv&.unlink
        end

        it "grants the badge to the users in the CSV as many times as they appear in it" do
          Jobs.run_immediately!
          badge.update!(multiple_grant: true)
          user_without_badge = Fabricate(:user)
          user_with_badge = Fabricate(:user).tap { |u| BadgeGranter.grant(badge, u) }

          csv_content =
            [
              user_with_badge.email.titlecase,
              user_with_badge.username.titlecase,
              user_without_badge.email.titlecase,
              user_without_badge.username.titlecase,
            ] * 20

          csv = Tempfile.new
          csv.write(csv_content.join("\n"))
          csv.rewind
          post "/admin/badges/award/#{badge.id}.json",
               params: {
                 file: fixture_file_upload(csv),
                 grant_existing_holders: true,
               }
          expect(response.status).to eq(200)
          expect(response.parsed_body["unmatched_entries"]).to eq([])
          expect(response.parsed_body["matched_users_count"]).to eq(2)
          expect(response.parsed_body["unmatched_entries_count"]).to eq(0)
          sequence = UserBadge.where(user: user_with_badge, badge: badge).pluck(:seq)
          expect(sequence.sort).to eq((0...(40 + 1)).to_a)
          sequence = UserBadge.where(user: user_without_badge, badge: badge).pluck(:seq)
          expect(sequence.sort).to eq((0...40).to_a)
        ensure
          csv&.close
          csv&.unlink
        end
      end
    end

    shared_examples "mass badge award not allowed" do
      it "prevents mass badge award with a 404 response" do
        file = file_from_fixtures("user_emails.csv", "csv")

        post "/admin/badges/award/#{badge.id}.json", params: { file: fixture_file_upload(file) }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(UserBadge.where(user: user, badge: badge).count).to eq(0)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "mass badge award not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "mass badge award not allowed"
    end
  end
end
