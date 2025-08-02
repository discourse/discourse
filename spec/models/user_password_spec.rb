# frozen_string_literal: true

RSpec.describe UserPassword do
  describe "#ensure_password_is_hashed" do
    let(:password) { SecureRandom.hex }
    fab!(:user_password)

    it "ensures password_hash, password_salt, password_algorithm are saved correctly" do
      user_password.update!(password:)

      expect(user_password.password_salt).not_to be_nil
      expect(user_password.password_algorithm).to eq(UserPassword::TARGET_PASSWORD_ALGORITHM)
      new_hash =
        described_class.new.send(
          :hash_password,
          password,
          user_password.password_salt,
          user_password.password_algorithm,
        )
      expect(user_password.password_hash).to eq(new_hash)
    end

    it "does not hash the password if no password given" do
      expect { user_password.update!(password: nil) }.not_to change(user_password, :password_hash)
    end

    context "when password was expired" do
      fab!(:expired_user_password)

      it "resets expired password to nil when saving new password" do
        expect { expired_user_password.update!(password: SecureRandom.hex) }.to change(
          expired_user_password,
          :password_expired_at,
        ).to(nil)
      end

      it "does not remove password_expired_at if no password given" do
        expect { expired_user_password.update!(password: nil) }.not_to change(
          user_password,
          :password_expired_at,
        )
      end
    end
  end

  describe "#confirm_password?" do
    context "when input password is same as saved password" do
      let(:pw) { SecureRandom.hex }

      it "returns true after saving password for the first time" do
        u = Fabricate(:user, password: nil)
        u.password = pw
        u.save!
        expect(u.confirm_password?(pw)).to eq true
      end

      it "returns true after updating existing password" do
        pw = SecureRandom.hex
        u = Fabricate(:user, password: "initial_password_123")
        u.update!(password: pw)
        expect(u.confirm_password?(pw)).to eq true
      end

      it "updates the algorithm if it's outdated and password_hash, and returns true" do
        user_password = Fabricate(:user, password: pw).user_password
        old_algorithm = "$pbkdf2-sha256$i=5,l=32$"
        old_hash =
          described_class.new.send(:hash_password, pw, user_password.password_salt, old_algorithm)
        user_password.update_columns(password_algorithm: old_algorithm, password_hash: old_hash)

        result = nil
        expect { result = user_password.confirm_password?(pw) }.to change {
          user_password.password_algorithm
        }.from(old_algorithm).to(described_class::TARGET_PASSWORD_ALGORITHM)
        expect(result).to eq true

        new_hash =
          described_class.new.send(
            :hash_password,
            pw,
            user_password.password_salt,
            user_password.password_algorithm,
          )
        expect(user_password.password_hash).to eq(new_hash)
      end
    end

    context "when input password is not the same as saved password" do
      let(:actual_pw) { SecureRandom.hex }

      it "returns false" do
        u = Fabricate(:user, password: actual_pw)
        expect(u.confirm_password?(SecureRandom.hex)).to eq false
      end
    end

    context "when used on an unpersisted record" do
      it "returns false" do
        user_password = Fabricate.build(:user_password, user: nil)
        expect(user_password.confirm_password?(user_password.password)).to eq false
      end
    end
  end

  context "for validations" do
    it "should validate presence of user_id" do
      user_password = Fabricate.build(:user_password, user: nil)

      expect(user_password).not_to be_valid
      expect(user_password.errors[:user]).to include("must exist")
    end
  end
end
