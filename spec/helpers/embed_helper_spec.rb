require 'rails_helper'

describe EmbedHelper do
  describe "embed_post_date" do
    subject { embed_post_date(dt) }

    context "with a date that is right now" do
      let(:dt) { Time.now }
      it "shows less than 1 minute because this test runs quickly" do
        expect(subject).to eq "< 1m"
      end
    end

    context "with a date that is right now" do
      let(:dt) { 5.minutes.ago }
      it "shows less than 1 minute because this test runs quickly" do
        Timecop.freeze(Time.new(2016, 4, 1)) do
          expect(subject).to eq "5m"
        end
      end
    end

    context "with a date from more than a month ago" do
      let(:dt) { Time.new(2016, 3, 1) }
      it "" do
        Timecop.freeze(Time.new(2016, 4, 1)) do
          expect(subject).to eq " 1 Mar"
        end
      end

      context "with a date from more than a year ago" do
        let(:dt) { Time.new(2011, 3, 1) }
        it "" do
          Timecop.freeze(Time.new(2016, 4, 1)) do
            expect(subject).to eq "Mar '11"
          end
        end
      end
    end
  end
end
