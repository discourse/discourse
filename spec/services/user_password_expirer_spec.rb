# frozen_string_literal: true

RSpec.describe UserPasswordExpirer do
  fab!(:password) { "somerandompassword" }
  fab!(:user) { Fabricate(:user, password:) }

  describe ".expire_user_password" do
    it "should update `UserPassword#password_expired_at` if the user already has an existing UserPassword record with the same password hash, salt and algorithm" do
      freeze_time(1.hour.ago) do
        described_class.expire_user_password(user)

        expect(user.reload.user_password.password_expired_at).to eq_time(Time.zone.now)
      end

      freeze_time do
        expect { described_class.expire_user_password(user) }.not_to change(UserPassword, :count)

        user_password = user.user_password.reload

        expect(user_password.password_hash).to eq(user.password_hash)
        expect(user_password.password_salt).to eq(user.salt)
        expect(user_password.password_algorithm).to eq(user.password_algorithm)
        expect(user_password.password_expired_at).to eq_time(Time.zone.now)
      end
    end

    it "updates UserPassword attributes if user already has an existing UserPassword record which has a different password_hash" do
      new_password = password + "_new"
      old_password_hash = user.password_hash

      freeze_time(1.hour.ago) do
        described_class.expire_user_password(user)

        expect(user.user_password.password_hash).to eq(old_password_hash)
        expect(user.user_password.password_expired_at).to eq_time(Time.zone.now)
      end

      freeze_time do
        user.update!(password: new_password)
        expect { described_class.expire_user_password(user) }.not_to change(UserPassword, :count)

        user_password = user.user_password.reload

        expect(user_password.password_hash).not_to eq(old_password_hash)
        expect(user_password.password_hash).to eq(user.password_hash)
        expect(user_password.password_salt).to eq(user.salt)
        expect(user_password.password_algorithm).to eq(user.password_algorithm)
        expect(user_password.password_expired_at).to eq_time(Time.zone.now)
      end
    end
  end
end
