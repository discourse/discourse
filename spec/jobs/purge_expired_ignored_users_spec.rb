# frozen_string_literal: true

require 'rails_helper'

describe Jobs::PurgeExpiredIgnoredUsers do
  subject { Jobs::PurgeExpiredIgnoredUsers.new.execute({}) }

  context "with no ignored users" do
    it "does nothing" do
      expect { subject }.to_not change { IgnoredUser.count }
    end
  end

  context "when some ignored users exist" do
    fab!(:tarek) { Fabricate(:user, username: "tarek") }
    fab!(:matt) { Fabricate(:user, username: "matt") }
    fab!(:john) { Fabricate(:user, username: "john") }

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
      fab!(:fred) { Fabricate(:user, username: "fred") }

      it "purges expired ignored users" do
        freeze_time(5.months.ago) do
          Fabricate(:ignored_user, user: tarek, ignored_user: fred)
        end

        subject
        expect(IgnoredUser.find_by(ignored_user: fred)).to be_nil
      end
    end

    context "when there are expired ignored users by expiring_at" do
      fab!(:fred) { Fabricate(:user, username: "fred") }

      it "purges expired ignored users" do
        Fabricate(:ignored_user, user: tarek, ignored_user: fred, expiring_at: 1.month.from_now)

        freeze_time(2.months.from_now) do
          subject
          expect(IgnoredUser.find_by(ignored_user: fred)).to be_nil
        end
      end
    end
  end
end
