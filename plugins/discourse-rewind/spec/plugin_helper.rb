# frozen_string_literal: true

module DiscourseRewindSpecHelper
  def call_report
    # user + date should be defined via fab! in the spec
    described_class.call(user:, date:, guardian: user.guardian)
  end

  def random_datetime
    # date should be defined via fab! in the spec
    date.to_a.sample.to_datetime + rand(0..23).hours + rand(0..59).minutes + rand(0..59).seconds
  end
end

RSpec.configure { |config| config.include DiscourseRewindSpecHelper }
