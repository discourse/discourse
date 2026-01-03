# frozen_string_literal: true

RSpec.describe(DiscourseRewind::FetchReport) do
  describe ".call" do
    subject(:result) { described_class.call(**dependencies) }

    fab!(:current_user, :user)

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { index: 0 } }
    let(:dependencies) { { guardian:, params: } }

    before { SiteSetting.discourse_rewind_enabled = true }

    context "when index is not provided" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when index is negative" do
      let(:params) { { index: -1 } }

      it { is_expected.to fail_a_contract }
    end

    context "when index is out of bounds" do
      before { freeze_time DateTime.parse("2021-12-22") }

      let(:params) { { index: 999 } }

      it { is_expected.to fail_to_find_a_model(:report) }
    end

    context "when in january" do
      before { freeze_time DateTime.parse("2021-01-22") }

      let(:params) { { index: 0 } }

      it "fetches reports from the previous year" do
        expect(result.year).to eq(2020)
        expect(result).to be_success
      end
    end

    context "when out of valid months" do
      before { freeze_time DateTime.parse("2021-02-22") }

      it { is_expected.to fail_to_find_a_model(:year) }
    end

    context "in development mode" do
      before do
        Rails.env.stubs(:development?).returns(true)
        freeze_time DateTime.parse("2021-06-22")
      end

      let(:params) { { index: 0 } }

      it "finds the year no matter what month" do
        expect(result.year).to eq(2021)
        expect(result).to be_success
      end
    end

    context "when a report is cached" do
      before { freeze_time DateTime.parse("2021-12-22") }

      context "when index is 0" do
        let(:params) { { index: 0 } }

        before do
          cached_report = { data: "cached top words", identifier: "top-words" }
          DiscourseRewind::FetchReportsHelper.cache_single_report(
            current_user.username,
            2021,
            "TopWords",
            cached_report,
          )
        end

        it "returns the cached report" do
          allow(DiscourseRewind::Action::TopWords).to receive(:call)
          expect(result).to be_success
          expect(result.report[:identifier]).to eq("top-words")
          expect(result.report[:data]).to eq("cached top words")
          expect(DiscourseRewind::Action::TopWords).to_not have_received(:call)
        end
      end

      context "when index is 1" do
        let(:params) { { index: 1 } }

        before do
          cached_report = { data: "cached reading time", identifier: "reading-time" }
          DiscourseRewind::FetchReportsHelper.cache_single_report(
            current_user.username,
            2021,
            "ReadingTime",
            cached_report,
          )
        end

        it "returns the cached report" do
          allow(DiscourseRewind::Action::ReadingTime).to receive(:call)
          expect(result).to be_success
          expect(result.report[:identifier]).to eq("reading-time")
          expect(DiscourseRewind::Action::ReadingTime).to_not have_received(:call)
        end
      end

      context "when index is beyond INITIAL_REPORT_COUNT" do
        let(:params) { { index: 3 } }

        before do
          cached_report = { data: "cached reactions", identifier: "reactions" }
          DiscourseRewind::FetchReportsHelper.cache_single_report(
            current_user.username,
            2021,
            "Reactions",
            cached_report,
          )
        end

        it "returns the cached report even though it's beyond INITIAL_REPORT_COUNT" do
          allow(DiscourseRewind::Action::Reactions).to receive(:call)
          expect(result).to be_success
          expect(result.report[:identifier]).to eq("reactions")
          expect(DiscourseRewind::Action::Reactions).to_not have_received(:call)
        end
      end
    end

    context "when a report is not cached" do
      before { freeze_time DateTime.parse("2021-12-22") }

      context "when index is 0" do
        let(:params) { { index: 0 } }

        it "generates and caches the report" do
          allow(DiscourseRewind::Action::TopWords).to receive(:call).and_return(
            { data: "generated top words", identifier: "top-words" },
          )
          expect(result).to be_success
          expect(result.report[:identifier]).to eq("top-words")
          expect(result.report[:data]).to eq("generated top words")
          expect(DiscourseRewind::Action::TopWords).to have_received(:call)

          cached =
            DiscourseRewind::FetchReportsHelper.load_single_report_from_cache(
              current_user.username,
              2021,
              "TopWords",
            )
          expect(cached[:identifier]).to eq("top-words")
        end
      end

      context "when index is beyond INITIAL_REPORT_COUNT" do
        let(:params) { { index: 3 } }

        it "generates and caches the report even though it's beyond INITIAL_REPORT_COUNT" do
          allow(DiscourseRewind::Action::Reactions).to receive(:call).and_return(
            { data: "generated reactions", identifier: "reactions" },
          )
          expect(result).to be_success
          expect(result.report[:identifier]).to eq("reactions")
          expect(DiscourseRewind::Action::Reactions).to have_received(:call)

          cached =
            DiscourseRewind::FetchReportsHelper.load_single_report_from_cache(
              current_user.username,
              2021,
              "Reactions",
            )
          expect(cached[:identifier]).to eq("reactions")
        end
      end
    end

    context "with for_user_username parameter" do
      fab!(:other_user, :user)
      fab!(:admin, :admin)

      before { freeze_time DateTime.parse("2021-12-22") }

      context "when for_user_username is blank" do
        let(:params) { { index: 0, for_user_username: "" } }

        it "uses the guardian user" do
          expect(result).to be_success
          expect(result.for_user).to eq(current_user)
        end
      end

      context "when for_user_username is provided but user does not exist" do
        let(:params) { { index: 0, for_user_username: "nonexistent" } }

        it { is_expected.to fail_to_find_a_model(:for_user) }
      end

      context "when viewing own rewind" do
        let(:params) { { index: 0, for_user_username: current_user.username } }

        it "returns the user's report" do
          expect(result).to be_success
          expect(result.for_user).to eq(current_user)
        end
      end

      context "when viewing another user's rewind" do
        context "when the other user has sharing enabled" do
          before { other_user.user_option.update!(discourse_rewind_share_publicly: true) }

          let(:params) { { index: 0, for_user_username: other_user.username } }

          before do
            cached_report = { data: "other user report", identifier: "top-words" }
            DiscourseRewind::FetchReportsHelper.cache_single_report(
              other_user.username,
              2021,
              "TopWords",
              cached_report,
            )
          end

          it "allows access to the report" do
            expect(result).to be_success
            expect(result.for_user).to eq(other_user)
            expect(result.report[:identifier]).to eq("top-words")
            expect(result.report[:data]).to eq("other user report")
          end

          context "when the other user has hide_profile enabled" do
            before { other_user.user_option.update!(hide_profile: true) }

            it { is_expected.to fail_to_find_a_model(:for_user) }
          end
        end

        context "when the other user has sharing disabled" do
          before { other_user.user_option.update!(discourse_rewind_share_publicly: false) }

          context "when guardian is an admin" do
            let(:guardian) { Guardian.new(admin) }
            let(:params) { { index: 0, for_user_username: other_user.username } }

            before do
              cached_report = { data: "other user report", identifier: "top-words" }
              DiscourseRewind::FetchReportsHelper.cache_single_report(
                other_user.username,
                2021,
                "TopWords",
                cached_report,
              )
            end

            it "allows access to the report" do
              expect(result).to be_success
              expect(result.for_user).to eq(other_user)
              expect(result.report[:identifier]).to eq("top-words")
              expect(result.report[:data]).to eq("other user report")
            end
          end

          context "when guardian is not an admin" do
            let(:params) { { index: 0, for_user_username: other_user.username } }

            it { is_expected.to fail_to_find_a_model(:for_user) }
          end
        end
      end
    end
  end
end
