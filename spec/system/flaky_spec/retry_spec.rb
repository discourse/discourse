# frozen_string_literal: true
# rubocop:disable RSpec/BeforeAfterAll

RSpec.describe "Testing FlakySpec::Retry on system tests" do
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

  _previous_example = nil

  context "when test fails 2 times before passing on third try", order: :defined do
    before(:all) { set_expectations(["not ok", "not ok", "ok"]) }

    before { count_up }

    after(:all) do
      reset_expectations
      reset_count
      _previous_example = nil
    end

    it "should retry the example 2 times", type: :system, flaky_spec_retry: true do
      visit("/srv/status")

      expect(page).to have_content(shift_expectation)
      expect(count).to eq(3)

      _previous_example = RSpec.current_example
    end

    it "should store the right failure details in metadata of the flaky example" do
      expect(_previous_example.metadata[:flaky_spec][:retry_attempts]).to eq(2)
      expect(_previous_example.metadata[:flaky_spec][:failed_examples].size).to eq(2)

      _previous_example.metadata[:flaky_spec][:failed_examples].each do |failed_example|
        expect(failed_example[:message_lines]).to include(<<~OUTPUT.chomp)
        Failure/Error: expect(page).to have_content(shift_expectation)
          expected to find text "not ok" in "ok"
        OUTPUT

        expect(failed_example[:description]).to eq(
          "Testing FlakySpec::Retry on system tests when test fails 2 times before passing on third try should retry the example 2 times",
        )

        expect(failed_example[:backtrace]).to be_present

        expect(failed_example[:failure_screenshot_path]).to match(
          %r{tmp/capybara/failures_r_spec_example_groups_testing_flaky_spec_retry_on_system_tests_when_test_fails2_times_before_passing_on_third_try_should_retry_the_example_2_times_(\d+).png},
        )
      end
    end
  end
end
