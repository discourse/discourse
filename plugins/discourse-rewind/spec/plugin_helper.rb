# frozen_string_literal: true

module DiscourseRewindSpecHelper
  def date
    Time.zone.local(2021).all_year
  end

  def call_report
    described_class.call(user:, date:)
  end

  def random_datetime
    rand(date.first.to_time...date.last.to_time)
  end
end

RSpec.configure { |config| config.include DiscourseRewindSpecHelper }
