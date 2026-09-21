# frozen_string_literal: true

RSpec.describe(DiscourseRewind::FetchReports) do
  describe ".call" do
    subject(:result) { described_class.call(guardian:, params:) }

    fab!(:current_user, :user)
    fab!(:other_user, :user)

    let(:guardian) { current_user.guardian }
    let(:params) { {} }

    before do
      SiteSetting.discourse_rewind_enabled = true
      freeze_time DateTime.parse("2021-12-22")
    end

    it "returns the initial reports and the total available" do
      expect(result).to have_attributes(
        year: 2021,
        for_user: current_user,
        reports: [
          nil,
          include(identifier: "reading-time"),
          include(identifier: "writing-analysis"),
        ],
        total_available: described_class::REPORTS.size,
      )
    end

    context "when in january" do
      before { freeze_time DateTime.parse("2021-01-22") }

      it "uses the previous year" do
        expect(result.year).to eq(2020)
      end
    end

    context "when out of valid months" do
      before { freeze_time DateTime.parse("2021-02-22") }

      it { is_expected.to fail_to_find_a_model(:year) }
    end

    context "when out of valid months in development" do
      before do
        Rails.env.stubs(:development?).returns(true)
        freeze_time DateTime.parse("2021-06-22")
      end

      it "uses the current year" do
        expect(result.year).to eq(2021)
      end
    end

    context "when a report fails" do
      it "keeps the other reports at their position and retries the failed one" do
        DiscourseRewind::Action::ReadingTime.stubs(:call).raises(StandardError)

        expect(
          described_class
            .call(guardian:, params:)
            .reports
            .map { |report| report&.dig(:identifier) },
        ).to eq([nil, nil, "writing-analysis"])

        DiscourseRewind::Action::ReadingTime.unstub(:call)

        expect(result.reports.map { |report| report&.dig(:identifier) }).to eq(
          [nil, "reading-time", "writing-analysis"],
        )
      end
    end

    context "when a report was already generated" do
      it "returns the cached report, even when it had no data" do
        DiscourseRewind::Action::TopWords.stubs(:call).returns(data: [1], identifier: "top-words")
        DiscourseRewind::Action::ReadingTime.stubs(:call).returns(nil)
        described_class.call(guardian:, params:)
        DiscourseRewind::Action::TopWords.stubs(:call).returns(data: [1], identifier: "changed")
        DiscourseRewind::Action::ReadingTime.stubs(:call).returns(
          data: [1],
          identifier: "reading-time",
        )

        expect(result.reports.first(2)).to eq([{ data: [1], identifier: "top-words" }, nil])
      end
    end

    context "with every report returning data" do
      let(:params) { { offset: 3 } }

      before do
        described_class::REPORTS.each do |report_class|
          report = { data: [1], identifier: report_class.name.demodulize }
          report_class.stubs(:call).returns(report)
          report_class.stubs(:filter_for_viewer).returns(report)
        end
      end

      def reports_named(*names)
        names.map { |name| { data: [1], identifier: name } }
      end

      it "returns the page of reports starting at the offset" do
        expect(result).to have_attributes(
          reports: reports_named("Reactions", "Fbff", "MostViewedTags"),
          total_available: described_class::REPORTS.size,
        )
      end

      it "returns null for reports without data" do
        DiscourseRewind::Action::Fbff.stubs(:filter_for_viewer).returns(
          data: [],
          identifier: "Fbff",
        )

        expect(result.reports).to eq(
          [*reports_named("Reactions"), nil, *reports_named("MostViewedTags")],
        )
      end
    end

    context "when the offset is negative" do
      let(:params) { { offset: -1 } }

      it { is_expected.to fail_a_contract }
    end

    context "when the offset is past the last report" do
      let(:params) { { offset: described_class::REPORTS.size } }

      it { is_expected.to fail_a_contract }
    end

    context "when a report contains a topic the viewer cannot see" do
      fab!(:visible_topic, :topic)
      fab!(:shared_draft_topic) { Fabricate(:shared_draft).topic }

      let(:params) do
        { offset: described_class::REPORTS.index(DiscourseRewind::Action::BestTopics) }
      end

      it "filters the report for the viewer" do
        DiscourseRewind::Action::BestTopics.stubs(:call).returns(
          data: [{ topic_id: visible_topic.id }, { topic_id: shared_draft_topic.id }],
          identifier: "best-topics",
        )

        expect(result.reports.first[:data]).to contain_exactly(topic_id: visible_topic.id)
      end

      it "returns null when the viewer can see none of the report" do
        DiscourseRewind::Action::BestTopics.stubs(:call).returns(
          data: [{ topic_id: shared_draft_topic.id }],
          identifier: "best-topics",
        )

        expect(result.reports.first).to be_nil
      end
    end

    context "when the user does not exist" do
      let(:params) { { for_user_username: "nonexistent" } }

      it { is_expected.to fail_to_find_a_model(:for_user) }
    end

    context "when viewing own rewind by username" do
      let(:params) { { for_user_username: current_user.username } }

      it "returns the user's rewind" do
        expect(result.for_user).to eq(current_user)
      end
    end

    context "when the other user shares their rewind" do
      let(:params) { { for_user_username: other_user.username } }

      before { other_user.user_option.update!(discourse_rewind_share_publicly: true) }

      it "returns the other user's rewind" do
        expect(result.for_user).to eq(other_user)
      end

      it "fails when the other user hides their profile" do
        other_user.user_option.update!(hide_profile: true)

        expect(result).to fail_to_find_a_model(:for_user)
      end
    end

    context "when the other user does not share their rewind" do
      let(:params) { { for_user_username: other_user.username } }

      it { is_expected.to fail_to_find_a_model(:for_user) }

      it "returns the other user's rewind to an admin" do
        current_user.update!(admin: true)

        expect(result.for_user).to eq(other_user)
      end
    end
  end
end
