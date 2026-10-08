# frozen_string_literal: true

describe GroupMutations do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, username: "ichigo") }
  fab!(:user_1) { Fabricate(:user, username: "rukia") }

  describe ".ensure_not_automatic!" do
    it "raises for an automatic group" do
      expect {
        described_class.ensure_not_automatic!(Group.find(Group::AUTO_GROUPS[:trust_level_1]))
      }.to raise_error(
        GroupMutations::AutomaticGroup,
        I18n.t("groups.errors.can_not_modify_automatic"),
      )
    end

    it "allows a custom group" do
      expect { described_class.ensure_not_automatic!(Fabricate(:group)) }.not_to raise_error
    end
  end

  describe ".resolve_users" do
    it "finds users by username regardless of case" do
      expect(
        described_class.resolve_users(guardian: admin.guardian, usernames: "ICHIGO").pluck(:id),
      ).to eq([user.id])
    end

    it "accepts a comma separated list and an array" do
      expect(
        described_class.resolve_users(guardian: admin.guardian, usernames: "ichigo,rukia").pluck(
          :id,
        ),
      ).to contain_exactly(user.id, user_1.id)
      expect(
        described_class.resolve_users(guardian: admin.guardian, usernames: %w[ichigo rukia]).pluck(
          :id,
        ),
      ).to contain_exactly(user.id, user_1.id)
    end

    it "prefers usernames over the other selectors" do
      expect(
        described_class.resolve_users(
          guardian: admin.guardian,
          usernames: "ichigo",
          user_ids: [user_1.id],
        ).pluck(:id),
      ).to eq([user.id])
    end

    it "keeps partial matches for existing HTTP callers" do
      expect(
        described_class.resolve_users(
          guardian: admin.guardian,
          usernames: [user.username, "missing_user"],
        ).pluck(:id),
      ).to eq([user.id])
    end

    it "rejects incomplete ID and email selections when all accounts are required" do
      expect do
        described_class.resolve_users(
          guardian: admin.guardian,
          user_ids: [user.id, 999_999_999],
          require_all: true,
        )
      end.to raise_error(
        GroupMutations::UnknownUsers,
        I18n.t("groups.errors.users_not_found", values: "999999999"),
      )

      expect do
        described_class.resolve_users(
          guardian: admin.guardian,
          user_emails: [user.email.upcase, "missing@example.com"],
          require_all: true,
        )
      end.to raise_error(
        GroupMutations::UnknownUsers,
        I18n.t("groups.errors.users_not_found", values: "missing@example.com"),
      )
    end

    it "finds users by id and by email" do
      expect(
        described_class.resolve_users(guardian: admin.guardian, user_ids: [user.id]).pluck(:id),
      ).to eq([user.id])
      expect(
        described_class.resolve_users(guardian: admin.guardian, user_emails: user.email).pluck(:id),
      ).to eq([user.id])
    end

    it "returns no users when no selector is given" do
      expect(described_class.resolve_users(guardian: admin.guardian)).to be_empty
    end

    it "raises naming the selector that matched nothing" do
      expect {
        described_class.resolve_users(guardian: admin.guardian, usernames: "nobody")
      }.to raise_error(Discourse::InvalidParameters)
      expect {
        described_class.resolve_users(guardian: admin.guardian, user_ids: [-999_999])
      }.to raise_error(Discourse::InvalidParameters)
      expect {
        described_class.resolve_users(guardian: admin.guardian, user_emails: "nobody@example.com")
      }.to raise_error(Discourse::InvalidParameters)
    end
  end
end
