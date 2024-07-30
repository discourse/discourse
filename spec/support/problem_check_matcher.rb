# frozen_string_literal: true

RSpec::Matchers.define :be_chill_about_it do
  match { |service| expect(service.call).to be_empty }
end

RSpec::Matchers.define :have_a_problem do
  chain :with_message do |message|
    @message = message
  end

  chain :with_priority do |priority|
    @priority = priority
  end

  match do |service|
    @result = service.call

    aggregate_failures do
      expect(@result).to include(be_a(ProblemCheck::Problem))
      expect(@result.first.priority).to(eq(@priority.to_s)) if @priority.present?
      expect(@result.first.message).to(eq(@message)) if @message.present?
    end
  end

  failure_message do |service|
    if @result.empty?
      "Expected check to have a problem, but it was chill about it."
    elsif !@result.all?(ProblemCheck::Problem)
      "Expected result to contain only instances of `Problem`."
    elsif @priority.present? && @result.first.priority != @priority
      "Expected problem to have priority `#{@priority}`, but got priority `#{@result.first.priority}`."
    elsif @message.present? && @result.first.message != @message
      <<~MESSAGE
        Expected problem to have message:

          > #{@message}

        but got message:

          > #{@result.first.message}
      MESSAGE
    end
  end
end
