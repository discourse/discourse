# frozen_string_literal: true

RSpec.describe EmailBounceScore do
  describe ".for_user" do
    it "matches every address the user owns, whatever case they are stored in" do
      user = Fabricate(:user, email: "primary@example.com")
      Fabricate(:secondary_email, user: user, email: "secondary@example.com")
      user.user_emails.update_all("email = upper(email)")
      EmailBounceScore.record_bounce!("primary@example.com", 1.0)
      EmailBounceScore.record_bounce!("secondary@example.com", 1.0)
      EmailBounceScore.record_bounce!("someone-else@example.com", 1.0)

      expect(EmailBounceScore.for_user(user).pluck(:email)).to contain_exactly(
        "primary@example.com",
        "secondary@example.com",
      )
    end
  end

  describe ".deliverable?" do
    it "is true for an address that has never bounced" do
      expect(EmailBounceScore.deliverable?("john@example.com")).to eq(true)
    end

    it "is false from the threshold up" do
      EmailBounceScore.record_bounce!("john@example.com", SiteSetting.bounce_score_threshold)

      expect(EmailBounceScore.deliverable?("john@example.com")).to eq(false)
    end

    it "is true below the threshold" do
      EmailBounceScore.record_bounce!("john@example.com", SiteSetting.bounce_score_threshold - 1)

      expect(EmailBounceScore.deliverable?("john@example.com")).to eq(true)
    end

    it "matches case-insensitively" do
      EmailBounceScore.record_bounce!("john@example.com", SiteSetting.bounce_score_threshold)

      expect(EmailBounceScore.deliverable?(" John@Example.COM ")).to eq(false)
    end
  end

  describe ".deliverable_sql" do
    def deliverable_user_ids
      User
        .joins(:user_emails)
        .where("user_emails.primary")
        .where(described_class.deliverable_sql)
        .pluck(:id)
    end

    it "selects an address with no row at all" do
      user = Fabricate(:user)

      expect(deliverable_user_ids).to include(user.id)
    end

    it "selects an address whose row is below the threshold" do
      user = Fabricate(:user)
      EmailBounceScore.record_bounce!(user.email, SiteSetting.bounce_score_threshold - 1)

      expect(deliverable_user_ids).to include(user.id)
    end

    it "rejects an address from the threshold up" do
      user = Fabricate(:user)
      EmailBounceScore.record_bounce!(user.email, SiteSetting.bounce_score_threshold)

      expect(deliverable_user_ids).not_to include(user.id)
    end

    it "rejects an address stored in a different case than the ledger key" do
      user = Fabricate(:user, email: "mixed@example.com")
      EmailBounceScore.record_bounce!("mixed@example.com", SiteSetting.bounce_score_threshold)
      user.user_emails.update_all(email: "MiXeD@Example.COM")

      expect(deliverable_user_ids).not_to include(user.id)
    end
  end

  describe "the user_stats mirror" do
    fab!(:user)

    it "follows a bounce, an erosion and a reset of the primary address" do
      EmailBounceScore.record_bounce!(user.email, 3.0)
      expect(user.user_stat.reload.bounce_score).to eq(3.0)
      expect(user.user_stat.reset_bounce_score_after).to be_present

      EmailBounceScore.erode!(user.email, 0.5)
      expect(user.user_stat.reload.bounce_score).to eq(2.5)

      EmailBounceScore.reset!(user.email)
      expect(user.user_stat.reload.bounce_score).to eq(0)
      expect(user.user_stat.reset_bounce_score_after).to eq(nil)
    end

    it "canonicalizes the address it was handed before looking for the owner" do
      EmailBounceScore.record_bounce!(user.email, 3.0)

      EmailBounceScore.erode!(" #{user.email.upcase} ", 0.5)

      expect(user.user_stat.reload.bounce_score).to eq(2.5)
    end

    it "ignores a bounce for an address the user only owns as a secondary" do
      Fabricate(:secondary_email, user: user, email: "secondary@example.com")

      EmailBounceScore.record_bounce!("secondary@example.com", 3.0)

      expect(user.user_stat.reload.bounce_score).to eq(0)
    end

    it "switches to the new address when the primary changes" do
      EmailBounceScore.record_bounce!(user.email, 3.0)

      user.primary_email.update!(email: "elsewhere@example.com")

      expect(user.user_stat.reload.bounce_score).to eq(0)
      expect(EmailBounceScore.score_for("elsewhere@example.com")).to eq(0)
    end

    it "follows a secondary address that gets promoted to primary" do
      secondary = Fabricate(:secondary_email, user: user, email: "secondary@example.com")
      EmailBounceScore.record_bounce!("secondary@example.com", 3.0)

      User.transaction do
        user.primary_email.update!(primary: false)
        secondary.update!(primary: true)
      end

      expect(user.user_stat.reload.bounce_score).to eq(3.0)
    end

    it "waits for the caller's transaction, so it can never roll the bounce back" do
      ActiveRecord::Base.transaction do
        EmailBounceScore.record_bounce!(user.email, 3.0)
        expect(user.user_stat.reload.bounce_score).to eq(0)
      end

      expect(user.user_stat.reload.bounce_score).to eq(3.0)
    end

    it "is left alone when a bounce lands on an address nobody owns" do
      EmailBounceScore.record_bounce!("nobody@example.com", 3.0)

      expect(user.user_stat.reload.bounce_score).to eq(0)
    end

    it "does not let a failure to sync take down the write that triggered it" do
      UserStat.expects(:refresh_bounce_score!).raises(StandardError.new("boom"))

      expect { user.primary_email.update!(email: "elsewhere@example.com") }.not_to raise_error
      expect(user.reload.email).to eq("elsewhere@example.com")
    end
  end

  describe ".reset_for_user!" do
    fab!(:user)

    it "clears every address the user owns" do
      Fabricate(:secondary_email, user: user, email: "secondary@example.com")
      EmailBounceScore.record_bounce!(user.email, 3.0)
      EmailBounceScore.record_bounce!("secondary@example.com", 3.0)
      EmailBounceScore.record_bounce!("someone-else@example.com", 3.0)

      EmailBounceScore.reset_for_user!(user)

      expect(EmailBounceScore.pluck(:email)).to contain_exactly("someone-else@example.com")
      expect(user.user_stat.reload.bounce_score).to eq(0)
    end

    it "clears the mirror of a user who has no primary address" do
      EmailBounceScore.record_bounce!(user.email, 3.0)
      user.user_emails.update_all(primary: false)

      EmailBounceScore.reset_for_user!(user)

      expect(user.user_stat.reload.bounce_score).to eq(0)
      expect(user.user_stat.reset_bounce_score_after).to eq(nil)
    end
  end

  describe ".record_bounce!" do
    it "creates a row for the first bounce and accumulates on subsequent ones" do
      EmailBounceScore.record_bounce!("john@example.com", 1.0)
      EmailBounceScore.record_bounce!("john@example.com", 2.0)

      expect(EmailBounceScore.score_for("john@example.com")).to eq(3.0)
    end

    it "stores the canonical address and matches case-insensitively" do
      EmailBounceScore.record_bounce!(" John.Doe@Example.COM ", 1.0)

      row = EmailBounceScore.for_email("john.doe@example.com").first
      expect(row.email).to eq("john.doe@example.com")

      EmailBounceScore.record_bounce!("JOHN.DOE@example.com", 1.0)
      expect(EmailBounceScore.count).to eq(1)
    end

    it "re-arms the reset window on every bounce" do
      freeze_time

      EmailBounceScore.record_bounce!("john@example.com", 1.0)
      row = EmailBounceScore.for_email("john@example.com").first
      expect(row.reset_bounce_score_after).to eq_time(
        SiteSetting.reset_bounce_score_after_days.days.from_now,
      )

      freeze_time(2.days.from_now)
      EmailBounceScore.record_bounce!("john@example.com", 1.0)
      expect(row.reload.reset_bounce_score_after).to eq_time(
        SiteSetting.reset_bounce_score_after_days.days.from_now,
      )
    end

    it "ignores addresses it could never have sent to" do
      EmailBounceScore.record_bounce!("", 1.0)
      EmailBounceScore.record_bounce!(nil, 1.0)
      EmailBounceScore.record_bounce!("not an address", 1.0)

      expect(EmailBounceScore.count).to eq(0)
    end

    it "returns the row as it stands after the bounce" do
      EmailBounceScore.record_bounce!("john@example.com", 1.0)

      recorded = EmailBounceScore.record_bounce!("john@example.com", 2.0)

      expect(recorded.bounce_score).to eq(3.0)
      expect(recorded.reset_bounce_score_after).to be_present
    end

    it "returns nothing for an address it ignored" do
      expect(EmailBounceScore.record_bounce!("not an address", 1.0)).to eq(nil)
    end
  end

  describe ".erode!" do
    it "lowers the score" do
      EmailBounceScore.record_bounce!("john@example.com", 1.0)

      EmailBounceScore.erode!("john@example.com", 0.1)

      expect(EmailBounceScore.score_for("john@example.com")).to eq(0.9)
    end

    it "floors the score at zero rather than leaving a residue" do
      EmailBounceScore.record_bounce!("john@example.com", 1.0)

      11.times { EmailBounceScore.erode!("john@example.com", 0.1) }

      expect(EmailBounceScore.score_for("john@example.com")).to eq(0)
    end
  end

  describe ".reset!" do
    it "removes the address's row" do
      EmailBounceScore.record_bounce!("john@example.com", 1.0)

      EmailBounceScore.reset!("John@Example.com")

      expect(EmailBounceScore.for_email("john@example.com")).to be_empty
    end
  end

  describe ".ensure_consistency!" do
    it "removes rows whose reset window has passed" do
      EmailBounceScore.record_bounce!("expired@example.com", 1.0)
      # the sweep compares against the database clock, which freeze_time can't move
      EmailBounceScore.for_email("expired@example.com").update_all(
        reset_bounce_score_after: 1.day.ago,
      )
      EmailBounceScore.record_bounce!("active@example.com", 1.0)

      EmailBounceScore.ensure_consistency!

      expect(EmailBounceScore.pluck(:email)).to contain_exactly("active@example.com")
    end

    it "removes rows that eroded back to zero" do
      EmailBounceScore.record_bounce!("eroded@example.com", 1.0)
      EmailBounceScore.erode!("eroded@example.com", 1.0)
      EmailBounceScore.record_bounce!("active@example.com", 1.0)

      EmailBounceScore.ensure_consistency!

      expect(EmailBounceScore.pluck(:email)).to contain_exactly("active@example.com")
    end

    describe "repairing the user_stats mirror" do
      fab!(:user)

      it "corrects a mirror that drifted away from a live row" do
        EmailBounceScore.record_bounce!(user.email, 3.0)
        user.user_stat.update_columns(bounce_score: 99.0)

        EmailBounceScore.ensure_consistency!

        expect(user.user_stat.reload.bounce_score).to eq(3.0)
      end

      it "clears a mirror whose address no longer has a row" do
        user.user_stat.update_columns(bounce_score: 3.0, reset_bounce_score_after: 1.week.from_now)

        EmailBounceScore.ensure_consistency!

        expect(user.user_stat.reload.bounce_score).to eq(0)
        expect(user.user_stat.reset_bounce_score_after).to eq(nil)
      end

      it "clears a mirror once the sweep drops the expired row it reflected" do
        EmailBounceScore.record_bounce!(user.email, 3.0)
        # the sweep compares against the database clock, which freeze_time can't move
        EmailBounceScore.for_email(user.email).update_all(reset_bounce_score_after: 1.day.ago)

        EmailBounceScore.ensure_consistency!

        expect(user.user_stat.reload.bounce_score).to eq(0)
      end

      it "does not let a secondary address hold the mirror up" do
        Fabricate(:secondary_email, user: user, email: "secondary@example.com")
        EmailBounceScore.record_bounce!("secondary@example.com", 3.0)
        user.user_stat.update_columns(bounce_score: 3.0)

        EmailBounceScore.ensure_consistency!

        expect(user.user_stat.reload.bounce_score).to eq(0)
      end

      it "clears the mirror of a user who has no primary address" do
        user.user_stat.update_columns(bounce_score: 3.0)
        user.user_emails.update_all(primary: false)

        EmailBounceScore.ensure_consistency!

        expect(user.user_stat.reload.bounce_score).to eq(0)
      end

      it "leaves a mirror that already agrees alone" do
        EmailBounceScore.record_bounce!(user.email, 3.0)

        # xmin changes on every UPDATE, even one that writes identical values
        expect { EmailBounceScore.ensure_consistency! }.not_to change {
          DB.query_single("SELECT xmin::text FROM user_stats WHERE user_id = ?", user.id)
        }
      end
    end
  end
end
