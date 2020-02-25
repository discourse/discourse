# frozen_string_literal: true

module Jobs

  class RetroGrantAnniversary < ::Jobs::Onceoff
    def execute_onceoff(args)
      return unless SiteSetting.enable_badges

      # Fill in the years of anniversary badges we missed
      (2..3).each do |year|
        ::Jobs::GrantAnniversaryBadges.new.execute(start_date: year.years.ago)
      end
    end
  end

end
