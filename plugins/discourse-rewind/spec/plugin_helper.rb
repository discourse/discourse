# frozen_string_literal: true

module DiscourseRewindSpecHelper
  def call_report
    # user + date should be defined via fab! in the spec
    described_class.call(user:, date:, guardian: user.guardian)
  end

  def random_datetime
    rand(date.first.to_time...date.last.to_time)
  end
end

RSpec.configure { |config| config.include DiscourseRewindSpecHelper }
