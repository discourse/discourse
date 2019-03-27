require 'rails_helper'

require_dependency 'jobs/scheduled/purge_expired_ignored_users'

describe Jobs::PurgeExpiredIgnoredUsers do
  subject { Jobs::PurgeExpiredIgnoredUsers.new.execute({}) }

  context "with no ignored users" do
    it "does nothing" do
      expect { subject }.to_not change { IgnoredUser.count }
    end
  end

  context "when some ignored users exist" do
    let(:tarek) { Fabricate(:user, username: "tarek") }
    let(:matt) { Fabricate(:user, username: "matt") }
    let(:john) { Fabricate(:user, username: "john") }

    before do
      Fabricate(:ignored_user, user: tarek, ignored_user: matt)
      Fabricate(:ignored_user, user: tarek, ignored_user: john)
    end

    context "when no expired ignored users" do
      it "does nothing" do
        expect { subject }.to_not change { IgnoredUser.count }
      end
    end

    context "when there are expired ignored users" do
      let(:fred) { Fabricate(:user, username: "fred") }

      it "purges expired ignored users" do
        freeze_time(5.months.ago) do
          Fabricate(:ignored_user, user: tarek, ignored_user: fred)
        end

        subject
        expect(IgnoredUser.find_by(ignored_user: fred)).to be_nil
      end
    end

    context "when there are expired ignored users by expiring_at" do
      let(:fred) { Fabricate(:user, username: "fred") }

      it "purges expired ignored users" do
        Fabricate(:ignored_user, user: tarek, ignored_user: fred, expiring_at: 5.months.from_now)

        freeze_time(6.months.from_now) do
          subject
          expect(IgnoredUser.find_by(ignored_user: fred)).to be_nil
        end
      end
    end
  end
end
