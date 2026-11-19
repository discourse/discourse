# frozen_string_literal: true

describe "Recalculate Scores Form" do
  let(:recalculate_scores_modal) { PageObjects::Modals::RecalculateScoresForm.new }

  fab!(:admin)
  fab!(:leaderboard, :gamification_leaderboard)

  before do
    RateLimiter.enable
    SiteSetting.discourse_gamification_enabled = true
    DiscourseGamification::LeaderboardCachedView.new(leaderboard).create
    sign_in(admin)
  end

  def format_date(date)
    date.midnight.strftime("%b %-d, %Y")
  end

  it "shows the date range for each preset" do
    freeze_time

    visit("/admin/plugins/gamification")
    find(".leaderboard-admin__btn-recalculate").click

    today = format_date(Time.now)

    expect(recalculate_scores_modal.date_range.text).to eq("#{format_date(10.days.ago)} - #{today}")

    recalculate_scores_modal.select_update_range("last_30_days")
    expect(recalculate_scores_modal.date_range.text).to eq("#{format_date(30.days.ago)} - #{today}")

    recalculate_scores_modal.select_update_range("last_90_days")
    expect(recalculate_scores_modal.date_range.text).to eq("#{format_date(90.days.ago)} - #{today}")

    recalculate_scores_modal.select_update_range("last_year")
    expect(recalculate_scores_modal.date_range.text).to eq("#{format_date(1.year.ago)} - #{today}")

    recalculate_scores_modal.select_update_range("all_time")
    expect(recalculate_scores_modal).to have_no_date_range
    expect(recalculate_scores_modal).to have_no_since_date_field
  end

  context "when admin has daily recalculation remaining" do
    it "can trigger recalculation" do
      visit("/admin/plugins/gamification")
      find(".leaderboard-admin__btn-recalculate").click

      recalculate_scores_modal.submit_button.click

      expect(recalculate_scores_modal.status).to have_content(
        I18n.t("js.gamification.recalculating"),
      )
      expect(recalculate_scores_modal).to have_disabled_submit_button

      expect(Jobs::RecalculateScores.jobs.count).to eq(1)
    end

    it "requires a date for a custom range" do
      visit("/admin/plugins/gamification")
      find(".leaderboard-admin__btn-recalculate").click

      recalculate_scores_modal.select_update_range("custom_date_range")
      expect(recalculate_scores_modal).to have_since_date_field

      recalculate_scores_modal.submit_button.click
      expect(recalculate_scores_modal.form.field("from_date")).to have_errors(
        I18n.t("js.form_kit.errors.required"),
      )
      expect(Jobs::RecalculateScores.jobs.count).to eq(0)

      recalculate_scores_modal.fill_since_date(5.days.ago.to_date)
      recalculate_scores_modal.submit_button.click

      expect(recalculate_scores_modal.status).to have_content(
        I18n.t("js.gamification.recalculating"),
      )
      expect(Jobs::RecalculateScores.jobs.count).to eq(1)
    end
  end

  context "when admin does not have daily recalculation remaining" do
    it "disables the submit button" do
      5.times { DiscourseGamification::RecalculateScoresRateLimiter.perform! }

      visit("/admin/plugins/gamification")
      find(".leaderboard-admin__btn-recalculate").click

      expect(recalculate_scores_modal).to have_disabled_submit_button
    end
  end
end
