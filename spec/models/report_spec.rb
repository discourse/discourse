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

  describe 'user to user private messages with replies' do
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

    context 'private message from system user' do
      before do
        Fabricate(:private_message_post, created_at: 1.hour.ago, user: Discourse.system_user)
      end

      it 'does not include system users' do
        expect(report.data).to be_blank
        expect(report.total).to eq 0
      end
    end
  end

  describe 'user to user private messages' do
    let(:report) { Report.find('user_to_user_private_messages') }

    context 'private message from system user' do
      before do
        Fabricate(:private_message_post, created_at: 1.hour.ago, user: Discourse.system_user)
      end

      it 'does not include system users' do
        expect(report.data).to be_blank
        expect(report.total).to eq 0
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
        expect(report.data[0][:ctr]).to eq(33.4)

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

  describe 'flags_status' do
    let(:report) { Report.find('flags_status') }

    context "no flags" do
      it "returns an empty report" do
        expect(report.data).to be_blank
      end
    end

    context "with flags" do
      let(:flagger) { Fabricate(:user) }
      let(:post) { Fabricate(:post) }

      before do
        PostAction.act(flagger, post, PostActionType.types[:spam], message: 'bad')
      end

      it "returns a report with data" do
        expect(report.data).to be_present

        row = report.data[0]
        expect(row[:action_type]).to eq("spam")
        expect(row[:staff_username]).to eq(nil)
        expect(row[:staff_id]).to eq(nil)
        expect(row[:staff_url]).to eq(nil)
        expect(row[:poster_username]).to eq(post.user.username)
        expect(row[:poster_id]).to eq(post.user.id)
        expect(row[:poster_url]).to eq("/admin/users/#{post.user.id}/#{post.user.username}")
        expect(row[:flagger_id]).to eq(flagger.id)
        expect(row[:flagger_username]).to eq(flagger.username)
        expect(row[:flagger_url]).to eq("/admin/users/#{flagger.id}/#{flagger.username}")
        expect(row[:resolution]).to eq("No action")
        expect(row[:response_time]).to eq(nil)
      end
    end
  end

  describe 'post_edits' do
    let(:report) { Report.find('post_edits') }

    context "no edits" do
      it "returns an empty report" do
        expect(report.data).to be_blank
      end
    end

    context "with edits" do
      let(:editor) { Fabricate(:user) }
      let(:post) { Fabricate(:post) }

      before do
        post.revise(editor, raw: 'updated body', edit_reason: 'not cool')
      end

      it "returns a report with data" do
        expect(report.data).to be_present
        expect(report.data.count).to be(1)

        row = report.data[0]
        expect(row[:editor_id]).to eq(editor.id)
        expect(row[:editor_username]).to eq(editor.username)
        expect(row[:editor_url]).to eq("/admin/users/#{editor.id}/#{editor.username}")
        expect(row[:author_id]).to eq(post.user.id)
        expect(row[:author_username]).to eq(post.user.username)
        expect(row[:author_url]).to eq("/admin/users/#{post.user.id}/#{post.user.username}")
        expect(row[:edit_reason]).to eq("not cool")
        expect(row[:post_id]).to eq(post.id)
        expect(row[:post_url]).to eq("/t/-/#{post.topic.id}/#{post.post_number}")
      end
    end
  end

  describe 'moderator activity' do
    let(:current_report) { Report.find('moderators_activity', start_date: 1.months.ago.beginning_of_day, end_date: Date.today) }
    let(:previous_report) { Report.find('moderators_activity', start_date: 2.months.ago.beginning_of_day, end_date: 1.month.ago.end_of_day) }

    context "no moderators" do
      it "returns an empty report" do
        expect(current_report.data).to be_blank
      end
    end

    context "with moderators" do
      before do
        freeze_time(Date.today)

        bob = Fabricate(:user, moderator: true, username: 'bob')
        bob.user_visits.create(visited_at: 2.days.ago, time_read: 200)
        bob.user_visits.create(visited_at: 1.day.ago, time_read: 100)
        Fabricate(:topic, user: bob, created_at: 1.day.ago)
        sally = Fabricate(:user, moderator: true, username: 'sally')
        sally.user_visits.create(visited_at: 2.days.ago, time_read: 1000)
        sally.user_visits.create(visited_at: 1.day.ago, time_read: 2000)
        topic = Fabricate(:topic)
        2.times {
          Fabricate(:post, user: sally, topic: topic, created_at: 1.day.ago)
        }
        flag_user = Fabricate(:user)
        flag_post = Fabricate(:post, user: flag_user)
        action = PostAction.new(user_id: flag_user.id,
                                post_action_type_id: PostActionType.types[:off_topic],
                                post_id: flag_post.id,
                                agreed_by_id: sally.id,
                                created_at: 1.day.ago,
                                agreed_at: Time.now)
        action.save
        bob.user_visits.create(visited_at: 45.days.ago, time_read: 200)
        old_topic = Fabricate(:topic, user: bob, created_at: 45.days.ago)
        3.times {
          Fabricate(:post, user: bob, topic: old_topic, created_at: 45.days.ago)
        }
        old_flag_user = Fabricate(:user)
        old_flag_post = Fabricate(:post, user: old_flag_user, created_at: 45.days.ago)
        old_action = PostAction.new(user_id: old_flag_user.id,
                                    post_action_type_id: PostActionType.types[:spam],
                                    post_id: old_flag_post.id,
                                    agreed_by_id: bob.id,
                                    created_at: 44.days.ago,
                                    agreed_at: 44.days.ago)
        old_action.save
      end

      it "returns a report with data" do
        expect(current_report.data).to be_present
      end

      it "returns data for two moderators" do
        expect(current_report.data.count).to eq(2)
      end

      it "returns the correct usernames" do
        expect(current_report.data[0][:username]).to eq('bob')
        expect(current_report.data[1][:username]).to eq('sally')
      end

      it "returns the correct read times" do
        expect(current_report.data[0][:time_read]).to eq(300)
        expect(current_report.data[1][:time_read]).to eq(3000)
      end

      it "returns the correct agreed flag count" do
        expect(current_report.data[0][:flag_count]).to be_blank
        expect(current_report.data[1][:flag_count]).to eq(1)
      end

      it "returns the correct topic count" do
        expect(current_report.data[0][:topic_count]).to eq(1)
        expect(current_report.data[1][:topic_count]).to be_blank
      end

      it "returns the correct post count" do
        expect(current_report.data[0][:post_count]).to be_blank
        expect(current_report.data[1][:post_count]).to eq(2)
      end

      it "returns the correct data for the time period" do
        expect(previous_report.data[0][:flag_count]).to eq(1)
        expect(previous_report.data[0][:topic_count]).to eq(1)
        expect(previous_report.data[0][:post_count]).to eq(3)
        expect(previous_report.data[0][:time_read]).to eq(200)

        expect(previous_report.data[1][:flag_count]).to be_blank
        expect(previous_report.data[1][:topic_count]).to be_blank
        expect(previous_report.data[1][:post_count]).to be_blank
        expect(previous_report.data[1][:time_read]).to be_blank
      end
    end
  end
end
