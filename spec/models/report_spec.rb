require 'rails_helper'

describe Report do

  describe "counting" do
    describe "requests" do
      before do
        freeze_time DateTime.parse('2017-03-01 12:00')

        # today, an incomplete day:
        ApplicationRequest.create(date: 0.days.ago.to_time, req_type: ApplicationRequest.req_types['http_total'], count: 1)

        # 60 complete days:
        30.times do |i|
          ApplicationRequest.create(date: (i + 1).days.ago.to_time, req_type: ApplicationRequest.req_types['http_total'], count: 10)
        end
        30.times do |i|
          ApplicationRequest.create(date: (31 + i).days.ago.to_time, req_type: ApplicationRequest.req_types['http_total'], count: 100)
        end
      end

      subject(:json) { Report.find("http_total_reqs").as_json }

      it "counts the correct records" do
        expect(json[:data].size).to eq(31) # today and 30 full days
        expect(json[:data][0..-2].sum { |d| d[:y] }).to eq(300)
        expect(json[:prev30Days]).to eq(3000)
      end
    end

    describe "topics" do
      before do
        Report.clear_cache
        freeze_time DateTime.parse('2017-03-01 12:00')

        ((0..32).to_a + [60, 61, 62, 63]).each do |i|
          Fabricate(:topic, created_at: i.days.ago)
        end
      end

      it "counts the correct records" do
        json = Report.find("topics").as_json
        expect(json[:data].size).to eq(31)
        expect(json[:prev30Days]).to eq(3)

        # lets make sure we can ask for the correct options for the report
        json = Report.find("topics",
          start_date: 5.days.ago.beginning_of_day,
          end_date: 1.day.ago.end_of_day,
          facets: [:prev_period]
        ).as_json

        expect(json[:prev_period]).to eq(5)
        expect(json[:data].length).to eq(5)
        expect(json[:prev30Days]).to eq(nil)
      end
    end
  end

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
          freeze_time DateTime.parse('2017-03-01 12:00')
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
      let(:report) { Report.find("#{request_type}_reqs", start_date: 10.days.ago.to_time, end_date: Time.now) }

      context "with no #{request_type} records" do
        it 'returns an empty report' do
          expect(report.data).to be_blank
        end
      end

      context "with #{request_type}" do
        before(:each) do
          freeze_time DateTime.parse('2017-03-01 12:00')
          ApplicationRequest.create(date: 35.days.ago.to_time, req_type: ApplicationRequest.req_types[request_type.to_s], count: 35)
          ApplicationRequest.create(date: 7.days.ago.to_time, req_type: ApplicationRequest.req_types[request_type.to_s], count: 8)
          ApplicationRequest.create(date: Time.now, req_type: ApplicationRequest.req_types[request_type.to_s], count: 1)
          ApplicationRequest.create(date: 1.day.ago.to_time, req_type: ApplicationRequest.req_types[request_type.to_s], count: 2)
          ApplicationRequest.create(date: 2.days.ago.to_time, req_type: ApplicationRequest.req_types[request_type.to_s], count: 3)
        end

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
    let(:report) { Report.find('user_to_user_private_messages_with_replies') }

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
        expect(report.data.find { |d| d[:x] == TrustLevel[0] }[:y]).to eq 3
        expect(report.data.find { |d| d[:x] == TrustLevel[2] }[:y]).to eq 2
        expect(report.data.find { |d| d[:x] == TrustLevel[4] }[:y]).to eq 1
      end
    end
  end

  describe 'new contributors report' do
    let(:report) { Report.find('new_contributors') }

    context "no contributors" do
      it "returns an empty report" do
        expect(report.data).to be_blank
      end
    end

    context "with contributors" do
      before do
        jeff = Fabricate(:user)
        jeff.user_stat = UserStat.new(new_since: 1.hour.ago, first_post_created_at: 1.day.ago)

        regis = Fabricate(:user)
        regis.user_stat = UserStat.new(new_since: 1.hour.ago, first_post_created_at: 2.days.ago)

        hawk = Fabricate(:user)
        hawk.user_stat = UserStat.new(new_since: 1.hour.ago, first_post_created_at: 2.days.ago)
      end

      it "returns a report with data" do
        expect(report.data).to be_present

        expect(report.data[0][:y]).to eq 2
        expect(report.data[1][:y]).to eq 1
      end
    end
  end

  describe 'users by types level report' do
    let(:report) { Report.find('users_by_type') }

    context "no users" do
      it "returns an empty report" do
        expect(report.data).to be_blank
      end
    end

    context "with users at different trust levels" do
      before do
        3.times { Fabricate(:user, admin: true) }
        2.times { Fabricate(:user, moderator: true) }
        UserSilencer.silence(Fabricate(:user), Fabricate.build(:admin))
        Fabricate(:user, suspended_till: 1.week.from_now, suspended_at: 1.day.ago)
      end

      it "returns a report with data" do
        expect(report.data).to be_present

        label = Proc.new { |key| I18n.t("reports.users_by_type.xaxis_labels.#{key}") }
        expect(report.data.find { |d| d[:x] == label.call("admin") }[:y]).to eq 3
        expect(report.data.find { |d| d[:x] == label.call("moderator") }[:y]).to eq 2
        expect(report.data.find { |d| d[:x] == label.call("silenced") }[:y]).to eq 1
        expect(report.data.find { |d| d[:x] == label.call("suspended") }[:y]).to eq 1
      end
    end
  end

  describe 'trending search report' do
    let(:report) { Report.find('trending_search') }

    context "no searches" do
      it "returns an empty report" do
        expect(report.data).to be_blank
      end
    end

    context "with different searches" do
      before do
        SearchLog.log(term: 'ruby', search_type: :header, ip_address: '127.0.0.1')

        SearchLog.create!(term: 'ruby', search_result_id: 1, search_type: 1, ip_address: '127.0.0.1', user_id: Fabricate(:user).id)

        SearchLog.log(term: 'ruby', search_type: :header, ip_address: '127.0.0.2')
        SearchLog.log(term: 'php', search_type: :header, ip_address: '127.0.0.1')
      end

      after do
        SearchLog.clear_debounce_cache!
      end

      it "returns a report with data" do
        expect(report.data[0][:term]).to eq("ruby")
        expect(report.data[0][:unique_searches]).to eq(2)
        expect(report.data[0][:ctr]).to eq('33.4%')

        expect(report.data[1][:term]).to eq("php")
        expect(report.data[1][:unique_searches]).to eq(1)
      end
    end
  end

  describe 'DAU/MAU report' do
    let(:report) { Report.find('dau_by_mau') }

    context "no activity" do
      it "returns an empty report" do
        expect(report.data).to be_blank
      end
    end

    context "with different users/visits" do
      before do
        freeze_time DateTime.parse('2017-03-01 12:00')

        arpit = Fabricate(:user)
        arpit.user_visits.create(visited_at:  1.day.ago)

        sam = Fabricate(:user)
        sam.user_visits.create(visited_at: 2.days.ago)

        robin = Fabricate(:user)
        robin.user_visits.create(visited_at: 2.days.ago)

        michael = Fabricate(:user)
        michael.user_visits.create(visited_at: 35.days.ago)

        gerhard = Fabricate(:user)
        gerhard.user_visits.create(visited_at: 45.days.ago)
      end

      it "returns a report with data" do
        expect(report.data.first[:y]).to eq(100)
        expect(report.data.last[:y]).to eq(33.34)
        expect(report.prev30Days).to eq(75)
      end
    end
  end

  describe 'Daily engaged users' do
    let(:report) { Report.find('daily_engaged_users') }

    context "no activity" do
      it "returns an empty report" do
        expect(report.data).to be_blank
      end
    end

    context "with different activities" do
      before do
        freeze_time DateTime.parse('2017-03-01 12:00')

        UserActionCreator.enable

        arpit = Fabricate(:user)
        sam = Fabricate(:user)

        jeff = Fabricate(:user, created_at: 1.day.ago)
        topic = Fabricate(:topic, user: jeff, created_at: 1.day.ago)
        post = Fabricate(:post, topic: topic, user: jeff, created_at: 1.day.ago)

        PostAction.act(arpit, post, PostActionType.types[:like])
        PostAction.act(sam, post, PostActionType.types[:like])
      end

      it "returns a report with data" do
        expect(report.data.first[:y]).to eq(1)
        expect(report.data.last[:y]).to eq(2)
      end
    end
  end

  describe 'posts counts' do
    it "only counts regular posts" do
      post = Fabricate(:post)
      Fabricate(:moderator_post, topic: post.topic)
      Fabricate.build(:post, post_type: Post.types[:whisper], topic: post.topic)
      post.topic.add_small_action(Fabricate(:admin), "invited_group", 'coolkids')
      r = Report.find('posts')
      expect(r.total).to eq(1)
      expect(r.data[0][:y]).to eq(1)
    end
  end
end
