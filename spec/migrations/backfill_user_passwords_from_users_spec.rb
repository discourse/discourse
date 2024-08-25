# frozen_string_literal: true

require "rails_helper"

require Rails.root.join("db/migrate/20240903024311_backfill_user_passwords_from_users.rb")

RSpec.describe BackfillUserPasswordsFromUsers do
  let(:migrate) { described_class.new.up }

  def assert_user_password_matches_user(user, user_password)
  end

  describe "#up" do
    context "when there is password data from users to backfill" do
      it "backfills user_passwords from users" do
        stub_const(described_class, "BATCH_SIZE", 2) do
          bot_user = Fabricate(:bot, password: SecureRandom.hex)
          user_with_password = Fabricate(:user, password: SecureRandom.hex)
          # simulates case where user_password is not automatically created
          users_without_user_passwords = [bot_user, user_with_password]
          users_without_user_passwords.map(&:reload).map(&:user_password).map(&:destroy!)

          Fabricate(:user, password: nil)

          user_with_different_password = Fabricate(:user, password: SecureRandom.hex)
          user_with_different_password.reload.user_password.update!(
            password_hash: "a" * 64,
            password_expired_at: Time.now,
          )

          expect { silence_stdout { migrate } }.to change { UserPassword.count }.by(
            users_without_user_passwords.length,
          )

          [*users_without_user_passwords, user_with_different_password].map(&:reload)
            .map do |user|
              user_password = user.user_password
              expect(user_password.password_hash).to eq(user.password_hash)
              expect(user_password.password_salt).to eq(user.salt)
              expect(user_password.password_algorithm).to eq(user.password_algorithm)
              expect(user_password.password_expired_at).to be_nil
            end
        end
      end
    end

    context "when password_hash from user matches its user_password" do
      it "does not update corresponding entry in user_passwords" do
        existing_user = Fabricate(:user, password: SecureRandom.hex)
        existing_user_password = existing_user.reload.user_password

        freeze_time(1.day.ago)
        existing_user_password.update!(
          created_at: Time.now,
          updated_at: Time.now,
          password_expired_at: Time.now,
        ) # simulate timestamps from past and expire the user password

        freeze_time(1.day.from_now)
        expect { silence_stdout { migrate } }.not_to change { UserPassword.count }

        expect(existing_user.reload.user_password).to have_attributes(
          existing_user_password.attributes,
        )
      end
    end

    context "when there is no new password data to backfill" do
      it "returns early without updating" do
        user = Fabricate(:user, password: nil)
        silence_stdout { migrate }
        expect(UserPassword.where(user_id: user.id).exists?).to eq(false)
      end
    end
  end
end
