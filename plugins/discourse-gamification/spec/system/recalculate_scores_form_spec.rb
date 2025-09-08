# frozen_string_literal: true

describe "Recalculate Scores Form", type: :system do
  let(:recalculate_scores_modal) { PageObjects::Modals::RecalculateScoresForm.new }

  fab!(:admin)
  fab!(:leaderboard) { Fabricate(:gamification_leaderboard) }

  before do
    RateLimiter.enable
    SiteSetting.discourse_gamification_enabled = true
    DiscourseGamification::LeaderboardCachedView.new(leaderboard).create
    sign_in(admin)
  end

  def format_date(date)
    date.midnight.strftime("%b %-d, %Y")
  end

  it "has date options that are valid and can be applied" do
    freeze_time

    visit("/admin/plugins/gamification")
    find(".leaderboard-admin__btn-recalculate").click

    today = format_date(Time.now)

    recalculate_scores_modal.select_update_range(value: 0)
    expect(recalculate_scores_modal.date_range.text).to eq("#{format_date(10.days.ago)} - #{today}")

    recalculate_scores_modal.select_update_range(value: 1)
    expect(recalculate_scores_modal.date_range.text).to eq("#{format_date(30.days.ago)} - #{today}")

    recalculate_scores_modal.select_update_range(value: 2)
    expect(recalculate_scores_modal.date_range.text).to eq("#{format_date(90.days.ago)} - #{today}")

    recalculate_scores_modal.select_update_range(value: 3)
    expect(recalculate_scores_modal.date_range.text).to eq("#{format_date(1.year.ago)} - #{today}")

    recalculate_scores_modal.select_update_range(value: 4)
    expect(recalculate_scores_modal.date_range.text).to eq("")

    recalculate_scores_modal.select_update_range(value: 5)
    expect(recalculate_scores_modal.custom_since_date).to be_visible

    recalculate_scores_modal.fill_since_date(today)
    expect(recalculate_scores_modal.custom_since_date.value).to eq(today)
  end

  context "when admin has daily recalculation remaining" do
    it "can trigger recalculation" do
      visit("/admin/plugins/gamification")
      find(".leaderboard-admin__btn-recalculate").click

      recalculate_scores_modal.apply.click

      expect(recalculate_scores_modal.status).to have_content(
        I18n.t("js.gamification.recalculating"),
      )
      expect(recalculate_scores_modal).to have_button("apply-section", disabled: true)

      expect(Jobs::RecalculateScores.jobs.count).to eq(1)
    end
  end

  context "when admin does not have daily recalculation remaining" do
    it "disables the 'apply' button" do
      5.times { DiscourseGamification::RecalculateScoresRateLimiter.perform! }

      visit("/admin/plugins/gamification")
      find(".leaderboard-admin__btn-recalculate").click

      expect(recalculate_scores_modal).to have_button("apply-section", disabled: true)
    end
  end
end
