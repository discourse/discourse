# frozen_string_literal: true

RSpec.describe EmailBounceScore do
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
  end
end
