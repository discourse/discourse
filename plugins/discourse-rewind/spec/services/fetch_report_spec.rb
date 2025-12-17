# frozen_string_literal: true

RSpec.describe(DiscourseRewind::FetchReport) do
  describe ".call" do
    subject(:result) { described_class.call(**dependencies) }

    fab!(:current_user, :user)

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { index: 0 } }
    let(:dependencies) { { guardian:, params: } }

    before do
      SiteSetting.discourse_rewind_enabled = true
      freeze_time DateTime.parse("2021-12-22")
      reports = [
        { type: "top_words", data: "report 1" },
        { type: "reading_time", data: "report 2" },
        { type: "writing_analysis", data: "report 3" },
      ]
      DiscourseRewind::FetchReportsHelper.cache_reports(current_user.username, 2021, reports)
    end

    context "when index is not provided" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when index is negative" do
      let(:params) { { index: -1 } }

      it { is_expected.to fail_a_contract }
    end

    context "when fetching a report by index" do
      context "when index is 0" do
        let(:params) { { index: 0 } }

        it "returns the first report" do
          expect(result).to be_success
          expect(result.report[:type]).to eq("top_words")
        end
      end

      context "when index is 1" do
        let(:params) { { index: 1 } }

        it "returns the second report" do
          expect(result).to be_success
          expect(result.report[:type]).to eq("reading_time")
        end
      end

      context "when index is out of bounds" do
        let(:params) { { index: 10 } }

        it { is_expected.to fail_to_find_a_model(:report) }
      end
    end

    context "when in january" do
      before do
        freeze_time DateTime.parse("2021-01-22")
        reports = [{ type: "top_words", data: "report 1" }]
        DiscourseRewind::FetchReportsHelper.cache_reports(current_user.username, 2020, reports)
      end

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
        reports = [{ type: "top_words", data: "report 1" }]
        DiscourseRewind::FetchReportsHelper.cache_reports(current_user.username, 2021, reports)
      end

      it "finds the year no matter what month" do
        expect(result.year).to eq(2021)
        expect(result).to be_success
      end
    end

    context "when reports are not cached" do
      before do
        Discourse.redis.del(
          DiscourseRewind::FetchReportsHelper.cache_key(current_user.username, 2021),
        )
      end

      it { is_expected.to fail_to_find_a_model(:all_reports) }
    end

    context "with for_user_username parameter" do
      fab!(:other_user, :user)
      fab!(:admin, :admin)

      before do
        freeze_time DateTime.parse("2021-12-22")
        reports = [
          { type: "top_words", data: "other user report 1" },
          { type: "reading_time", data: "other user report 2" },
        ]
        DiscourseRewind::FetchReportsHelper.cache_reports(other_user.username, 2021, reports)
      end

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

          it "allows access to the report" do
            expect(result).to be_success
            expect(result.for_user).to eq(other_user)
            expect(result.report[:type]).to eq("top_words")
            expect(result.report[:data]).to eq("other user report 1")
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

            it "allows access to the report" do
              expect(result).to be_success
              expect(result.for_user).to eq(other_user)
              expect(result.report[:type]).to eq("top_words")
              expect(result.report[:data]).to eq("other user report 1")
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
