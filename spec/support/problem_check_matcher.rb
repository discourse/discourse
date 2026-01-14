# frozen_string_literal: true

RSpec::Matchers.define :be_chill_about_it do
  match { |service| expect(service.call).to be_blank }
end

RSpec::Matchers.define :have_a_problem do
  chain :with_message do |message|
    @message = message
  end

  chain :with_priority do |priority|
    @priority = priority
  end

  chain :with_target do |target|
    @target = target
  end

  match do |service|
    @result = service.call

    aggregate_failures do
      expect(@result).to be_a(ProblemCheck::Problem)
      expect(@result.priority).to(eq(@priority.to_s)) if @priority.present?
      expect(@result.message).to(eq(@message)) if @message.present?
      expect(@result.target).to(eq(@target)) if @target.present?
    end
  end

  failure_message do |service|
    if @result.blank?
      "Expected check to have a problem, but it was chill about it."
    elsif !@result.is_a?(ProblemCheck::Problem)
      "Expected result to must be an instance of `Problem`."
    elsif @priority.present? && @result.priority != @priority
      "Expected problem to have priority `#{@priority}`, but got priority `#{@result.priority}`."
    elsif @message.present? && @result.message != @message
      <<~MESSAGE
        Expected problem to have message:

          > #{@message}

        but got message:

          > #{@result.message}
      MESSAGE
    elsif @target.present? && @result.target != @target
      "Expected problem to have target `#{@target}`, but got target `#{@result.target}`."
    end
  end
end
