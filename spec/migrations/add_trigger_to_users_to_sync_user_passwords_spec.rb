# frozen_string_literal: true

require "rails_helper"

require Rails.root.join("db/migrate/20240903024211_add_trigger_to_users_to_sync_user_passwords.rb")

RSpec.describe AddTriggerToUsersToSyncUserPasswords do
  describe "#up" do
    let(:rollback) { described_class.new.down }
    let(:migrate) { described_class.new.up }
    let!(:password) { SecureRandom.hex }

    before { silence_stdout { rollback } }

    context "when a new user is created" do
      before { silence_stdout { migrate } }

      context "with password" do
        it "creates a corresponding entry in user_passwords" do
          expect { Fabricate(:user, password: "someawesomepassword") }.to change {
            UserPassword.count
          }.by 1
          user_password = UserPassword.last
          user = user_password.user
          expect(user_password.password_hash).to eq(user.password_hash)
          expect(user_password.password_salt).to eq(user.salt)
          expect(user_password.password_algorithm).to eq(user.password_algorithm)
          expect(user_password.password_expired_at).to be_nil
        end
      end

      context "without password" do
        it "does not create corresponding entry in user_passwords" do
          expect { Fabricate(:user, password: nil) }.not_to change { UserPassword.count }
        end
      end
    end

    context "when an existing user is updated" do
      let!(:existing_user) { Fabricate(:user, password: nil) }

      before { silence_stdout { migrate } }

      context "with password while user has no existing password" do
        it "creates a corresponding entry in user_passwords" do
          expect { existing_user.update!(password: password) }.to change { UserPassword.count }.by 1
        end
      end

      context "with password while user has a different existing password" do
        it "updates the existing entry in user_passwords" do
          freeze_time(1.day.ago)
          existing_user.update!(password: password)
          existing_user.reload
          old_password = existing_user.user_password
          old_password.update!(created_at: Time.now, updated_at: Time.now) # simulate frozen timestamps from past

          freeze_time(1.day.from_now)
          expect { existing_user.update!(password: "#{password}_new") }.not_to change {
            UserPassword.count
          }

          new_password = existing_user.reload.user_password
          expect(new_password.id).to eq(old_password.id)
          expect(new_password.password_hash).not_to eq(old_password.password_hash)
          expect(new_password.created_at).to eq_time(old_password.created_at)
          expect(new_password.updated_at).not_to eq_time(old_password.updated_at)
        end
      end

      context "with password while user has the same existing password" do
        before { existing_user.update!(password: password) }

        it "raises validation error" do
          expect { existing_user.update!(password: password) }.to raise_error(
            ActiveRecord::RecordInvalid,
          )
        end
      end

      context "with password_hash while user had the same password_hash" do
        it "does not update corresponding entry in user_passwords" do
          freeze_time(1.day.ago)
          existing_user.update!(password: password)
          existing_user.reload
          old_password = existing_user.user_password
          old_password.update!(created_at: Time.now, updated_at: Time.now) # simulate frozen timestamps from past

          freeze_time(1.day.from_now)
          expect {
            existing_user.update_column(:password_hash, old_password.password_hash)
          }.not_to change { UserPassword.count }
          expect(existing_user.reload.user_password).to have_attributes(old_password.attributes)
        end
      end

      context "without password while user has no existing password" do
        it "does not create corresponding entry in user_passwords" do
          silence_stdout { migrate }
          expect { existing_user.update!(username: "Username", password: nil) }.not_to change {
            UserPassword.count
          }
          expect(existing_user.reload.user_password).to be_nil
        end
      end

      context "with null password_hash while user has a existing password" do
        it "deletes corresponding entry in user_passwords" do
          silence_stdout { migrate }

          existing_user.update!(password: password)

          expect { existing_user.update_column(:password_hash, nil) }.to change {
            UserPassword.count
          }.by(-1)
          expect(UserPassword.where(user_id: existing_user.id).exists?).to eq(false)
        end
      end
    end
  end
end
