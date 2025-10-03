# frozen_string_literal: true

describe "currently_away report" do
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:group_1) { Fabricate(:group) }

  before { group_1.add(user_1) }

  context "when users_on_holiday is not set" do
    it "does not generate report with data" do
      report = Report.find("currently_away", filters: { group: group_1.id })

      expect(report.data).to eq([])
      expect(report.total).to eq(0)
    end
  end

  context "when users_on_holiday is set" do
    before { DiscourseCalendar.users_on_holiday = [user_1.username] }

    it "generates a correct report" do
      report = Report.find("currently_away", filters: { group: group_1.id })

      expect(report.data).to contain_exactly({ username: user_1.username })
      expect(report.total).to eq(1)
    end
  end
end
