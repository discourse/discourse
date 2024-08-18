# frozen_string_literal: true

require Rails.root.join("db/migrate/20240818113758_remove_all_but_most_recent_user_password.rb")

RSpec.describe RemoveAllButMostRecentUserPassword do
  let(:migrate) { described_class.new.up }

  describe "#up" do
    context "when each user has only 1 user password" do
      fab!(:expired_user_password)
      fab!(:user_password)

      it "does not delete any records" do
        expect { silence_stdout { migrate } }.not_to change { UserPassword.count }
      end
    end

    context "when there are multiple passwords for a user" do
      fab!(:user)

      context "with NULL and non-NULL password_expired_at values" do
        let!(:unexpired_password) do
          Fabricate(:user_password, user: user, password_expired_at: nil)
        end

        before { 2.times { Fabricate(:expired_user_password, user: user) } }

        it "keeps only the unexpired password" do
          expect { silence_stdout { migrate } }.to change { UserPassword.count }.from(3).to(1)
          expect(UserPassword.first).to eq(unexpired_password)
        end
      end

      context "with only non-NULL password_expired_at values" do
        let!(:most_recently_expired_password) do
          Fabricate(:user_password, user: user, password_expired_at: 1.day.ago)
        end

        before do
          2.times { Fabricate(:user_password, user: user, password_expired_at: 2.days.ago) }
        end

        it "keeps the most recently expired password" do
          expect { silence_stdout { migrate } }.to change { UserPassword.count }.from(3).to(1)
          expect(UserPassword.first).to eq(most_recently_expired_password)
        end
      end
    end
  end
end
