# frozen_string_literal: true
# rubocop:disable RSpec/BeforeAfterAll
# rubocop:disable RSpec/ExpectActual

RSpec.describe FlakySpec::Retry, flaky_spec_retry: true do
  def set_expectations(expectations)
    @expectations = expectations
  end

  def shift_expectation
    @expectations.shift
  end

  def reset_expectations
    @expectations = nil
  end

  def count
    @count ||= 0
  end

  def count_up
    @count ||= 0
    @count += 1
  end

  def reset_count
    @count = 0
  end

  context "when test fails 2 times before passing on third try" do
    before(:all) { set_expectations([false, false, true]) }

    before { count_up }

    after(:all) do
      reset_expectations
      reset_count
    end

    it "should retry the example 2 times" do
      expect(true).to eq(shift_expectation)
      expect(count).to eq(3)

      current_example = RSpec.current_example

      expect(current_example.metadata[:flaky_spec][:retry_attempts]).to eq(2)
      expect(current_example.metadata[:flaky_spec][:failed_examples].size).to eq(2)

      first_failed_example = current_example.metadata[:flaky_spec][:failed_examples].first

      current_example.metadata[:flaky_spec][:failed_examples].each do |failed_example|
        expect(failed_example[:message_lines]).to eq(<<~OUTPUT.chomp)
        Failure/Error: expect(true).to eq(shift_expectation)

          expected: false
               got: true

          (compared using ==)

          Diff:
          @@ -1 +1 @@
          -false
          +true
        OUTPUT

        expect(failed_example[:description]).to eq(
          "FlakySpec::Retry when test fails 2 times before passing on third try should retry the example 2 times",
        )

        expect(failed_example[:backtrace]).to be_present
        expect(failed_example[:failure_screenshot_path]).to eq(nil)
      end
    end
  end

  context "when test fails 1 time before passing on second try" do
    before(:all) { set_expectations([false, true]) }

    before { count_up }

    after(:all) do
      reset_expectations
      reset_count
    end

    it "should retry the example 1 time" do
      expect(true).to eq(shift_expectation)
      expect(count).to eq(2)

      current_example = RSpec.current_example

      expect(current_example.metadata[:flaky_spec][:retry_attempts]).to eq(1)
      expect(current_example.metadata[:flaky_spec][:failed_examples].size).to eq(1)

      failed_example = current_example.metadata[:flaky_spec][:failed_examples].first

      expect(failed_example[:message_lines]).to eq(<<~OUTPUT.chomp)
      Failure/Error: expect(true).to eq(shift_expectation)

        expected: false
             got: true

        (compared using ==)

        Diff:
        @@ -1 +1 @@
        -false
        +true
      OUTPUT

      expect(failed_example[:description]).to eq(
        "FlakySpec::Retry when test fails 1 time before passing on second try should retry the example 1 time",
      )

      expect(failed_example[:backtrace]).to be_present
      expect(failed_example[:failure_screenshot_path]).to eq(nil)
    end
  end

  context "when test does not fail on first run" do
    before(:all) { set_expectations([true]) }

    before { count_up }

    after(:all) do
      reset_expectations
      reset_count
    end

    it "should not retry the example" do
      expect(true).to eq(shift_expectation)
      expect(count).to eq(1)

      current_example = RSpec.current_example

      expect(current_example.metadata[:flaky_spec][:retry_attempts]).to eq(nil)
      expect(current_example.metadata[:flaky_spec][:failed_examples]).to eq(nil)
    end
  end
end
