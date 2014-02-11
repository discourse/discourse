require 'reports/user_report'
module Jobs

  class MonthlyUsageReport < Jobs::Scheduled
    recurrence { monthly.day_of_month(1) }

    def execute(args)
      start_date = Date.today.beginning_of_month.ago(1.month)
      end_date = start_date.end_of_month
      UserReport.new(start_date, end_date, "Jeremy.Roegner@cph.org").generate!
    end

  end

end