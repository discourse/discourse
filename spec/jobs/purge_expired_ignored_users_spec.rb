require 'rails_helper'

require_dependency 'jobs/scheduled/purge_expired_ignored_users'

describe Jobs::PurgeExpiredIgnoredUsers do
  subject { Jobs::PurgeExpiredIgnoredUsers.new.execute({}) }

  context "with no ignored users" do
    it "does nothing" do
      subject
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
        subject
        expect { subject }.to_not change { IgnoredUser.count }
      end
    end

    context "when there are expired ignored users" do
      it "purges expired ignored users" do
        freeze_time(5.months.ago) do
          fred = Fabricate(:user, username: "fred")
          Fabricate(:ignored_user, user: tarek, ignored_user: fred)
        end

        expect { subject }.to change { IgnoredUser.count }.from(3).to(2)
      end
    end
  end
end
