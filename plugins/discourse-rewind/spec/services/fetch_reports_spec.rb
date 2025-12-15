# frozen_string_literal: true

RSpec.describe(DiscourseRewind::FetchReports) do
  describe ".call" do
    subject(:result) { described_class.call(**dependencies) }

    fab!(:current_user, :user)

    let(:guardian) { Guardian.new(current_user) }
    let(:dependencies) { { guardian: } }

    before { SiteSetting.discourse_rewind_enabled = true }

    context "when in january" do
      before { freeze_time DateTime.parse("2021-01-22") }

      it "computes the correct previous year" do
        expect(result.year).to eq(2020)
      end
    end

    context "when in december" do
      before { freeze_time DateTime.parse("2021-12-22") }

      it "computes the correct previous year" do
        expect(result.year).to eq(2021)
      end
    end

    context "when out of valid months december" do
      before { freeze_time DateTime.parse("2021-02-22") }

      it { is_expected.to fail_to_find_a_model(:year) }
    end

    context "in development mode" do
      before do
        Rails.env.stubs(:development?).returns(true)
        freeze_time DateTime.parse("2021-06-22")
      end

      it "finds the year no matter what month" do
        expect(result.year).to eq(2021)
      end
    end

    context "when reports is cached" do
      before { freeze_time DateTime.parse("2021-12-22") }

      it "returns the cached reports" do
        initial_count = result.reports.length
        expect(initial_count).to be > 0

        allow(DiscourseRewind::Action::TopWords).to receive(:call)
        expect(result.reports.length).to eq(initial_count)
        expect(DiscourseRewind::Action::TopWords).to_not have_received(:call)
      end
    end

    context "when reports is not cached" do
      before do
        freeze_time DateTime.parse("2021-01-22")
        Discourse.redis.del("rewind:#{current_user.username}:2020")
      end

      it "returns the reports" do
        allow(DiscourseRewind::Action::TopWords).to receive(:call)
        expect(result.reports.length).to be > 0
        expect(DiscourseRewind::Action::TopWords).to have_received(:call)
      end
    end

    context "with for_user_username parameter" do
      fab!(:other_user, :user)
      fab!(:admin, :admin)

      before { freeze_time DateTime.parse("2021-12-22") }

      context "when for_user_username is blank" do
        let(:dependencies) { { guardian:, params: { for_user_username: "" } } }

        it "uses the guardian user" do
          expect(result).to be_success
          expect(result.for_user).to eq(current_user)
        end
      end

      context "when for_user_username is provided but user does not exist" do
        let(:dependencies) { { guardian:, params: { for_user_username: "nonexistent" } } }

        it { is_expected.to fail_to_find_a_model(:for_user) }
      end

      context "when viewing own rewind" do
        let(:dependencies) { { guardian:, params: { for_user_username: current_user.username } } }

        it "returns the user's reports" do
          expect(result).to be_success
          expect(result.for_user).to eq(current_user)
        end
      end

      context "when viewing another user's rewind" do
        context "when the other user has sharing enabled" do
          before { other_user.user_option.update!(discourse_rewind_share_publicly: true) }

          let(:dependencies) { { guardian:, params: { for_user_username: other_user.username } } }

          it "allows access to the reports" do
            expect(result).to be_success
            expect(result.for_user).to eq(other_user)
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
            let(:dependencies) { { guardian:, params: { for_user_username: other_user.username } } }

            it "allows access to the reports" do
              expect(result).to be_success
              expect(result.for_user).to eq(other_user)
            end
          end

          context "when guardian is not an admin" do
            let(:dependencies) { { guardian:, params: { for_user_username: other_user.username } } }

            it { is_expected.to fail_to_find_a_model(:for_user) }
          end
        end
      end
    end
  end
end
