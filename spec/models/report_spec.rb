require 'spec_helper'

describe Report do

  describe 'visits report' do
    let(:report) { Report.find('visits') }

    context "no visits" do
      it "returns an empty report" do
        expect(report.data).to be_blank
      end
    end

    context "with visits" do
      let(:user) { Fabricate(:user) }

      it "returns a report with data" do
        freeze_time DateTime.parse('2000-01-01')
        user.user_visits.create(visited_at: 1.hour.from_now)
        user.user_visits.create(visited_at: 1.day.ago)
        user.user_visits.create(visited_at: 2.days.ago)
        expect(report.data).to be_present
        expect(report.data.select { |v| v[:x].today? }).to be_present
      end

    end
  end

  [:signup, :topic, :post, :flag, :like, :email].each do |arg|
    describe "#{arg} report" do
      pluralized = arg.to_s.pluralize

      let(:report) { Report.find(pluralized) }

      context "no #{pluralized}" do
        it 'returns an empty report' do
          expect(report.data).to be_blank
        end
      end

      context "with #{pluralized}" do
        before(:each) do
          Timecop.freeze
          fabricator = case arg
          when :signup
            :user
          when :email
            :email_log
          else
            arg
          end
          Fabricate(fabricator)
          Fabricate(fabricator, created_at: 1.hours.ago)
          Fabricate(fabricator, created_at: 1.hours.ago)
          Fabricate(fabricator, created_at: 1.day.ago)
          Fabricate(fabricator, created_at: 2.days.ago)
          Fabricate(fabricator, created_at: 30.days.ago)
          Fabricate(fabricator, created_at: 35.days.ago)
        end
        after(:each) { Timecop.return }

        context 'returns a report with data'
          it "returns today's data" do
            expect(report.data.select { |v| v[:x].today? }).to be_present
          end

          it 'returns total data' do
            expect(report.total).to eq 7
          end

          it "returns previous 30 day's data" do
            expect(report.prev30Days).to be_present
          end
        end
      end
    end

  [:http_total, :http_2xx, :http_background, :http_3xx, :http_4xx, :http_5xx, :page_view_crawler, :page_view_logged_in, :page_view_anon].each do |request_type|
    describe "#{request_type} request reports" do
      let(:report) { Report.find("#{request_type}_reqs", start_date: 10.days.ago.to_time, end_date: Date.today.to_time) }

      context "with no #{request_type} records" do
        it 'returns an empty report' do
          expect(report.data).to be_blank
        end
      end

      context "with #{request_type}" do
        before(:each) do
          Timecop.freeze
          ApplicationRequest.create(date: 35.days.ago.to_time, req_type: ApplicationRequest.req_types[request_type.to_s], count: 35)
          ApplicationRequest.create(date: 7.days.ago.to_time, req_type: ApplicationRequest.req_types[request_type.to_s], count: 8)
          ApplicationRequest.create(date: Date.today.to_time, req_type: ApplicationRequest.req_types[request_type.to_s], count: 1)
          ApplicationRequest.create(date: 1.day.ago.to_time, req_type: ApplicationRequest.req_types[request_type.to_s], count: 2)
          ApplicationRequest.create(date: 2.days.ago.to_time, req_type: ApplicationRequest.req_types[request_type.to_s], count: 3)
        end
        after(:each) { Timecop.return }


        context 'returns a report with data' do
          it "returns expected number of recoords" do
            expect(report.data.count).to eq 4
          end

          it 'sorts the data from oldest to latest dates' do
            expect(report.data[0][:y]).to eq(8) # 7 days ago
            expect(report.data[1][:y]).to eq(3) # 2 days ago
            expect(report.data[2][:y]).to eq(2) # 1 day ago
            expect(report.data[3][:y]).to eq(1) # today
          end

          it "returns today's data" do
            expect(report.data.select { |value| value[:x] == Date.today }).to be_present
          end

          it 'returns total data' do
            expect(report.total).to eq 49
          end

          it 'returns previous 30 days of data' do
            expect(report.prev30Days).to eq 35
          end
        end
      end
    end
  end

  describe 'private messages' do
    let(:report) { Report.find('user_to_user_private_messages') }

    it 'topic report).to not include private messages' do
      Fabricate(:private_message_topic, created_at: 1.hour.ago)
      Fabricate(:topic, created_at: 1.hour.ago)
      report = Report.find('topics')
      expect(report.data[0][:y]).to eq(1)
      expect(report.total).to eq(1)
    end

    it 'post report).to not include private messages' do
      Fabricate(:private_message_post, created_at: 1.hour.ago)
      Fabricate(:post)
      report = Report.find('posts')
      expect(report.data[0][:y]).to eq 1
      expect(report.total).to eq 1
    end

    context 'no private messages' do
      it 'returns an empty report' do
        expect(report.data).to be_blank
      end

      context 'some public posts' do
        it 'returns an empty report' do
          Fabricate(:post); Fabricate(:post)
          expect(report.data).to be_blank
          expect(report.total).to eq 0
        end
      end
    end

    context 'some private messages' do
      before do
        Fabricate(:private_message_post, created_at: 25.hours.ago)
        Fabricate(:private_message_post, created_at: 1.hour.ago)
        Fabricate(:private_message_post, created_at: 1.hour.ago)
      end

      it 'returns correct data' do
        expect(report.data[0][:y]).to eq 1
        expect(report.data[1][:y]).to eq 2
        expect(report.total).to eq 3
      end

      context 'and some public posts' do
        before do
          Fabricate(:post); Fabricate(:post)
        end

        it 'returns correct data' do
          expect(report.data[0][:y]).to eq 1
          expect(report.data[1][:y]).to eq 2
          expect(report.total).to eq 3
        end
      end
    end
  end

  describe 'users by trust level report' do
    let(:report) { Report.find('users_by_trust_level') }

    context "no users" do
      it "returns an empty report" do
        expect(report.data).to be_blank
      end
    end

    context "with users at different trust levels" do
      before do
        3.times { Fabricate(:user, trust_level: TrustLevel[0]) }
        2.times { Fabricate(:user, trust_level: TrustLevel[2]) }
        Fabricate(:user, trust_level: TrustLevel[4])
      end

      it "returns a report with data" do
        expect(report.data).to be_present
        expect(report.data.find {|d| d[:x] == TrustLevel[0]}[:y]).to eq 3
        expect(report.data.find {|d| d[:x] == TrustLevel[2]}[:y]).to eq 2
        expect(report.data.find {|d| d[:x] == TrustLevel[4]}[:y]).to eq 1
      end
    end
  end
end

