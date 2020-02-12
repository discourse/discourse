# frozen_string_literal: true

require 'rails_helper'

describe Report do
  let(:user) { Fabricate(:user) }  # id: 3
  let(:c0) { Fabricate(:category, user: user) }  # id: 3
  let(:c1) { Fabricate(:category, parent_category: c0, user: user) }  # id: 2
  let(:c2) { Fabricate(:category, user: user) }  # id: 4

  shared_examples 'no data' do
    context "with no data" do
      it 'returns an empty report' do
        expect(report.data).to be_blank
      end
    end
  end

  shared_examples 'category filtering' do
    it 'returns the filtered data' do
      expect(report.total).to eq 1
    end
  end

  shared_examples 'category filtering on subcategories' do
    it 'returns the filtered data' do
      expect(report.total).to eq(1)
    end
  end

  shared_examples 'with data x/y' do
    it "returns today's data" do
      expect(report.data.select { |v| v[:x].today? }).to be_present
    end

    it 'returns correct data for period' do
      expect(report.data[0][:y]).to eq 3
    end

    it 'returns total' do
      expect(report.total).to eq 4
    end

    it 'returns previous 30 day’s data' do
      expect(report.prev30Days).to be_present
    end
  end

  describe "counting" do
    describe "requests" do
      before do
        freeze_time DateTime.parse('2017-03-01 12:00')

        # today, an incomplete day:
        application_requests = [{ date: 0.days.ago.to_time, req_type: ApplicationRequest.req_types['http_total'], count: 1 }]

        # 60 complete days:
        30.times.each_with_object(application_requests) do |i|
          application_requests.concat([{ date: (i + 1).days.ago.to_time, req_type: ApplicationRequest.req_types['http_total'], count: 10  }])
        end
        30.times.each_with_object(application_requests) do |i|
          application_requests.concat([{ date: (31 + i).days.ago.to_time, req_type: ApplicationRequest.req_types['http_total'], count: 100 }])
        end

        ApplicationRequest.insert_all(application_requests)
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
        user = Fabricate(:user)
        topics = ((0..32).to_a + [60, 61, 62, 63]).map do |i|
          date = i.days.ago
          {
            user_id: user.id,
            last_post_user_id: user.id,
            title: "topic #{i}",
            category_id: SiteSetting.uncategorized_category_id,
            bumped_at: date,
            created_at: date,
            updated_at: date
          }
        end
        Topic.insert_all(topics)
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

    include_examples 'no data'

    context "with visits" do
      let(:user) { Fabricate(:user) }

      it "returns a report with data" do
        freeze_time DateTime.parse('2000-01-01')
        user.user_visits.create(visited_at: 1.hour.from_now)
        user.user_visits.create(visited_at: 1.day.ago)
        user.user_visits.create(visited_at: 2.days.ago, mobile: true)
        user.user_visits.create(visited_at: 45.days.ago)
        user.user_visits.create(visited_at: 46.days.ago, mobile: true)

        expect(report.data).to be_present
        expect(report.data.count).to eq(3)
        expect(report.data.select { |v| v[:x].today? }).to be_present
        expect(report.prev30Days).to eq(2)
      end
    end
  end

  describe 'mobile visits report' do
    let(:report) { Report.find('mobile_visits') }

    include_examples 'no data'

    context "with visits" do
      let(:user) { Fabricate(:user) }

      it "returns a report with data" do
        freeze_time DateTime.parse('2000-01-01')
        user.user_visits.create(visited_at: 1.hour.from_now)
        user.user_visits.create(visited_at: 2.days.ago, mobile: true)
        user.user_visits.create(visited_at: 45.days.ago)
        user.user_visits.create(visited_at: 46.days.ago, mobile: true)

        expect(report.data).to be_present
        expect(report.data.count).to eq(1)
        expect(report.data.select { |v| v[:x].today? }).not_to be_present
        expect(report.prev30Days).to eq(1)
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

          if arg == :flag
            user = Fabricate(:user)
            topic = Fabricate(:topic, user: user)
            builder = -> (dt) { PostActionCreator.create(user, Fabricate(:post, topic: topic, user: user), :spam, created_at: dt) }
          elsif arg == :signup
            builder = -> (dt) { Fabricate(:user, created_at: dt) }
          else
            user = Fabricate(:user)
            factories = { email: :email_log }
            builder = -> (dt) { Fabricate(factories[arg] || arg, created_at: dt, user: user) }
          end

          [DateTime.now, 1.hour.ago, 1.hour.ago, 1.day.ago, 2.days.ago, 30.days.ago, 35.days.ago].each(&builder)
        end

        it "returns today's, total and previous 30 day's data" do
          expect(report.data.select { |v| v[:x].today? }).to be_present
          expect(report.total).to eq 7
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
          application_requests = [
            { date: 35.days.ago.to_time, req_type: ApplicationRequest.req_types[request_type.to_s], count: 35 },
            { date: 7.days.ago.to_time, req_type: ApplicationRequest.req_types[request_type.to_s], count: 8 },
            { date: Time.now, req_type: ApplicationRequest.req_types[request_type.to_s], count: 1 },
            { date: 1.day.ago.to_time, req_type: ApplicationRequest.req_types[request_type.to_s], count: 2 },
            { date: 2.days.ago.to_time, req_type: ApplicationRequest.req_types[request_type.to_s], count: 3 }
          ]
          ApplicationRequest.insert_all(application_requests)
        end

        it 'returns a report with data' do
          # expected number of recoords
          expect(report.data.count).to eq 4

          # sorts the data from oldest to latest dates
          expect(report.data[0][:y]).to eq(8) # 7 days ago
          expect(report.data[1][:y]).to eq(3) # 2 days ago
          expect(report.data[2][:y]).to eq(2) # 1 day ago
          expect(report.data[3][:y]).to eq(1) # today

          # today's data
          expect(report.data.find { |value| value[:x] == Date.today }).to be_present

          # total data
          expect(report.total).to eq 49

          #previous 30 days of data
          expect(report.prev30Days).to eq 35
        end
      end
    end
  end

  describe 'user to user private messages with replies' do
    let(:report) { Report.find('user_to_user_private_messages_with_replies') }
    let(:user) { Fabricate(:user) }
    let(:topic) { Fabricate(:topic, created_at: 1.hour.ago, user: user) }

    it 'topic report).to not include private messages' do
      Fabricate(:private_message_topic, created_at: 1.hour.ago, user: user)
      topic
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
          Fabricate(:post, topic: topic, user: user); Fabricate(:post, topic: topic, user: user)
          expect(report.data).to be_blank
          expect(report.total).to eq 0
        end
      end
    end

    context 'some private messages' do
      before do
        Fabricate(:private_message_post, created_at: 25.hours.ago, user: user)
        Fabricate(:private_message_post, created_at: 1.hour.ago, user: user)
        Fabricate(:private_message_post, created_at: 1.hour.ago, user: user)
      end

      it 'returns correct data' do
        expect(report.data[0][:y]).to eq 1
        expect(report.data[1][:y]).to eq 2
        expect(report.total).to eq 3
      end

      context 'and some public posts' do
        before do
          Fabricate(:post, user: user, topic: topic)
          Fabricate(:post, user: user, topic: topic)
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

    include_examples 'no data'

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

    include_examples 'no data'

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

    include_examples 'no data'

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

    include_examples 'no data'

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
        expect(report.data[0][:searches]).to eq(3)
        expect(report.data[0][:ctr]).to eq(33.4)

        expect(report.data[1][:term]).to eq("php")
        expect(report.data[1][:searches]).to eq(1)
      end
    end
  end

  describe 'DAU/MAU report' do
    let(:report) { Report.find('dau_by_mau') }

    include_examples 'no data'

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

    include_examples 'no data'

    context "with different activities" do
      before do
        freeze_time DateTime.parse('2017-03-01 12:00')

        UserActionManager.enable

        arpit = Fabricate(:user)
        sam = Fabricate(:user)

        jeff = Fabricate(:user, created_at: 1.day.ago)
        post = create_post(user: jeff, created_at: 1.day.ago)
        PostActionCreator.like(arpit, post)
        PostActionCreator.like(sam, post)
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

    include_examples 'no data'

    context "with flags" do
      let(:flagger) { Fabricate(:user) }
      let(:post) { Fabricate(:post, user: flagger) }

      before do
        freeze_time

        PostActionCreator.new(flagger, post, PostActionType.types[:spam], message: 'bad').perform
      end

      it "returns a report with data" do
        expect(report.data).to be_present

        row = report.data[0]
        expect(row[:post_type]).to eq("spam")
        expect(row[:staff_username]).to eq(nil)
        expect(row[:staff_id]).to eq(nil)
        expect(row[:poster_username]).to eq(post.user.username)
        expect(row[:poster_id]).to eq(post.user.id)
        expect(row[:poster_avatar_template]).to be_present
        expect(row[:flagger_id]).to eq(flagger.id)
        expect(row[:flagger_username]).to eq(flagger.username)
        expect(row[:flagger_avatar_template]).to be_present
        expect(row[:resolution]).to eq("No action")
        expect(row[:response_time]).to eq(nil)
      end
    end
  end

  describe 'post_edits' do
    let(:report) { Report.find('post_edits') }

    include_examples 'no data'

    context "with edits" do
      let(:editor) { Fabricate(:user) }
      let(:post) { Fabricate(:post) }

      before do
        freeze_time

        post.revise(post.user, { raw: 'updated body by author', edit_reason: 'not cool' }, force_new_version: true)
        post.revise(editor, raw: 'updated body', edit_reason: 'not cool')
      end

      it "returns a report with data" do
        expect(report.data).to be_present
        expect(report.data.count).to be(1)

        row = report.data[0]
        expect(row[:editor_id]).to eq(editor.id)
        expect(row[:editor_username]).to eq(editor.username)
        expect(row[:editor_avatar_template]).to be_present
        expect(row[:author_id]).to eq(post.user.id)
        expect(row[:author_username]).to eq(post.user.username)
        expect(row[:author_avatar_template]).to be_present
        expect(row[:edit_reason]).to eq("not cool")
        expect(row[:post_raw]).to eq("updated body")
        expect(row[:post_number]).to eq(post.post_number)
        expect(row[:topic_id]).to eq(post.topic.id)
      end
    end
  end

  describe 'moderator activity' do
    let(:report) {
      Report.find('moderators_activity')
    }

    let(:sam) { Fabricate(:user, moderator: true, username: 'sam') }

    let(:jeff) { Fabricate(:user, moderator: true, username: 'jeff') }

    include_examples 'no data'

    context "with moderators" do
      before do
        freeze_time(Date.today)
      end

      context "moderators order" do
        before do
          Fabricate(:post, user: sam)
          Fabricate(:post, user: jeff)
        end

        it "returns the moderators in alphabetical order" do
          expect(report.data[0][:username]).to eq('jeff')
          expect(report.data[1][:username]).to eq('sam')
        end
      end

      context "time read" do
        before do
          sam.user_visits.create(visited_at: 2.days.ago, time_read: 200)
          sam.user_visits.create(visited_at: 1.day.ago, time_read: 100)

          jeff.user_visits.create(visited_at: 2.days.ago, time_read: 1000)
          jeff.user_visits.create(visited_at: 1.day.ago, time_read: 2000)

          Fabricate(:topic, created_at: 1.day.ago)
        end

        it "returns the correct read times" do
          expect(report.data[0][:username]).to eq('jeff')
          expect(report.data[0][:time_read]).to eq(3000)
          expect(report.data[1][:username]).to eq('sam')
          expect(report.data[1][:time_read]).to eq(300)
        end
      end

      context "flags" do
        before do
          flagged_post = Fabricate(:post)
          result = PostActionCreator.off_topic(jeff, flagged_post)
          result.reviewable.perform(jeff, :agree_and_keep)
        end

        it "returns the correct flag counts" do
          expect(report.data.count).to eq(1)
          expect(report.data[0][:flag_count]).to eq(1)
          expect(report.data[0][:username]).to eq("jeff")
        end
      end

      context "topics" do
        before do
          Fabricate(:topic, user: sam)
          Fabricate(:topic, user: sam)
          Fabricate(:topic, user: jeff)
        end

        it "returns the correct topic count" do
          expect(report.data[0][:topic_count]).to eq(1)
          expect(report.data[0][:username]).to eq('jeff')
          expect(report.data[1][:topic_count]).to eq(2)
          expect(report.data[1][:username]).to eq('sam')
        end

        context "private messages" do
          before do
            Fabricate(:private_message_topic, user: jeff)
          end

          it "doesn’t count private topic" do
            expect(report.data[0][:topic_count]).to eq(1)
            expect(report.data[1][:topic_count]).to eq(2)
          end
        end
      end

      context "posts" do
        before do
          Fabricate(:post, user: sam)
          Fabricate(:post, user: sam)
          Fabricate(:post, user: jeff)
        end

        it "returns the correct topic count" do
          expect(report.data[0][:topic_count]).to eq(1)
          expect(report.data[0][:username]).to eq('jeff')
          expect(report.data[1][:topic_count]).to eq(2)
          expect(report.data[1][:username]).to eq('sam')
        end

        context "private messages" do
          before do
            Fabricate(:private_message_post, user: jeff)
          end

          it "doesn’t count private post" do
            expect(report.data[0][:post_count]).to eq(1)
            expect(report.data[1][:post_count]).to eq(2)
          end
        end
      end

      context "private messages" do
        before do
          Fabricate(:post, user: sam)
          Fabricate(:post, user: jeff)
          Fabricate(:private_message_post, user: jeff)
        end

        it "returns the correct topic count" do
          expect(report.data[0][:pm_count]).to eq(1)
          expect(report.data[0][:username]).to eq('jeff')
          expect(report.data[1][:pm_count]).to be_blank
          expect(report.data[1][:username]).to eq('sam')

        end
      end

      context "revisions" do
        before do
          post = Fabricate(:post)
          post.revise(sam, raw: 'updated body', edit_reason: 'not cool')
        end

        it "returns the correct revisions count" do
          expect(report.data[0][:revision_count]).to eq(1)
          expect(report.data[0][:username]).to eq('sam')
        end

        context "revise own post" do
          before do
            post = Fabricate(:post, user: sam)
            post.revise(sam, raw: 'updated body')
          end

          it "doesn't count a revison on your own post" do
            expect(report.data[0][:revision_count]).to eq(1)
            expect(report.data[0][:username]).to eq('sam')
          end
        end
      end

      context "previous data" do
        before do
          Fabricate(:topic, user: sam, created_at: 1.year.ago)
        end

        it "doesn’t count old data" do
          expect(report.data[0][:topic_count]).to be_blank
          expect(report.data[0][:username]).to eq('sam')
        end
      end
    end
  end

  describe 'flags' do
    let(:report) { Report.find('flags') }

    include_examples 'no data'

    context 'with data' do
      include_examples 'with data x/y'

      before(:each) do
        user = Fabricate(:user)
        topic = Fabricate(:topic, user: user)
        post0 = Fabricate(:post, topic: topic, user: user)
        post1 = Fabricate(:post, topic: Fabricate(:topic, category: c1, user: user), user: user)
        post2 = Fabricate(:post, topic: topic, user: user)
        post3 = Fabricate(:post, topic: topic, user: user)
        PostActionCreator.off_topic(user, post0)
        PostActionCreator.off_topic(user, post1)
        PostActionCreator.off_topic(user, post2)
        PostActionCreator.create(user, post3, :off_topic, created_at: 45.days.ago)
      end

      context "with category filtering" do
        let(:report) { Report.find('flags', filters: { category: c1.id }) }

        include_examples 'category filtering'

        context "on subcategories" do
          let(:report) { Report.find('flags', filters: { category: c0.id }) }

          include_examples 'category filtering on subcategories'
        end
      end
    end
  end

  describe 'topics' do
    let(:report) { Report.find('topics') }

    include_examples 'no data'

    context 'with data' do
      include_examples 'with data x/y'

      before(:each) do
        user = Fabricate(:user)
        Fabricate(:topic, user: user)
        Fabricate(:topic, category: c1, user: user)
        Fabricate(:topic, user: user)
        Fabricate(:topic, created_at: 45.days.ago, user: user)
      end

      context "with category filtering" do
        let(:report) { Report.find('topics', filters: { category: c1.id }) }

        include_examples 'category filtering'

        context "on subcategories" do
          let(:report) { Report.find('topics', filters: { category: c0.id }) }

          include_examples 'category filtering on subcategories'
        end
      end
    end
  end

  describe "exception report" do
    before(:each) do
      class Report
        def self.report_exception_test(report)
          report.data = x
        end
      end
    end

    it "returns a report with an exception error" do
      report = Report.find("exception_test", wrap_exceptions_in_test: true)
      expect(report.error).to eq(:exception)
    end
  end

  describe "timeout report" do
    before(:each) do
      freeze_time

      class Report
        def self.report_timeout_test(report)
          report.error = wrap_slow_query(1) do
            ActiveRecord::Base.connection.execute("SELECT pg_sleep(5)")
          end
        end
      end
    end

    it "returns a report with a timeout error" do
      report = Report.find("timeout_test")
      expect(report.error).to eq(:timeout)
    end
  end

  describe "unexpected error on report initialization" do
    before do
      @orig_logger = Rails.logger
      Rails.logger = @fake_logger = FakeLogger.new
    end

    after do
      Rails.logger = @orig_logger
    end

    it "returns no report" do
      class ReportInitError < StandardError; end

      Report.stubs(:new).raises(ReportInitError.new("x"))

      report = Report.find('signups', wrap_exceptions_in_test: true)

      expect(report).to be_nil

      expect(Rails.logger.errors).to eq([
        'Couldn’t create report `signups`: <ReportInitError x>'
      ])
    end
  end

  describe 'posts' do
    let(:report) { Report.find('posts') }

    include_examples 'no data'

    context 'with data' do
      include_examples 'with data x/y'

      before(:each) do
        user = Fabricate(:user)
        topic = Fabricate(:topic, user: user)
        topic_with_category_id = Fabricate(:topic, category: c1, user: user)
        Fabricate(:post, topic: topic, user: user)
        Fabricate(:post, topic: topic_with_category_id, user: user)
        Fabricate(:post, topic: topic, user: user)
        Fabricate(:post, created_at: 45.days.ago, topic: topic, user: user)
      end

      context "with category filtering" do
        let(:report) { Report.find('posts', filters: { category: c1.id }) }

        include_examples 'category filtering'

        context "on subcategories" do
          let(:report) { Report.find('posts', filters: { category: c0.id }) }

          include_examples 'category filtering on subcategories'
        end
      end
    end
  end

  # TODO: time_to_first_response

  describe 'topics_with_no_response' do
    let(:report) { Report.find('topics_with_no_response') }

    include_examples 'no data'

    context 'with data' do
      include_examples 'with data x/y'

      before(:each) do
        user = Fabricate(:user)
        Fabricate(:topic, category: c1, user: user)
        Fabricate(:post, topic: Fabricate(:topic, user: user), user: user)
        Fabricate(:topic, user: user)
        Fabricate(:topic, created_at: 45.days.ago, user: user)
      end

      context "with category filtering" do
        let(:report) { Report.find('topics_with_no_response', filters: { category: c1.id }) }

        include_examples 'category filtering'

        context "on subcategories" do
          let(:report) { Report.find('topics_with_no_response', filters: { category: c0.id }) }

          include_examples 'category filtering on subcategories'
        end
      end
    end
  end

  describe 'likes' do
    let(:report) { Report.find('likes') }

    include_examples 'no data'

    context 'with data' do
      include_examples 'with data x/y'

      before(:each) do
        topic = Fabricate(:topic, category: c1)
        post = Fabricate(:post, topic: topic)
        PostActionCreator.like(Fabricate(:user), post)

        topic = Fabricate(:topic, category: c2)
        post = Fabricate(:post, topic: topic)
        PostActionCreator.like(Fabricate(:user), post)
        PostActionCreator.like(Fabricate(:user), post)
        PostActionCreator.like(Fabricate(:user), post).post_action.tap do |pa|
          pa.created_at = 45.days.ago
        end.save!
      end

      context "with category filtering" do
        let(:report) { Report.find('likes', filters: { category: c1.id }) }

        include_examples 'category filtering'

        context "on subcategories" do
          let(:report) { Report.find('likes', filters: { category: c0.id }) }

          include_examples 'category filtering on subcategories'
        end
      end
    end
  end

  describe 'user_flagging_ratio' do
    let(:joffrey) { Fabricate(:user, username: "joffrey") }
    let(:robin) { Fabricate(:user, username: "robin") }
    let(:moderator) { Fabricate(:moderator) }
    let(:user) { Fabricate(:user) }

    context 'with data' do
      it "it works" do
        topic = Fabricate(:topic, user: user)
        2.times do
          post_disagreed = Fabricate(:post, topic: topic, user: user)
          result = PostActionCreator.spam(joffrey, post_disagreed)
          result.reviewable.perform(moderator, :disagree)
        end

        3.times do
          post_disagreed = Fabricate(:post, topic: topic, user: user)
          result = PostActionCreator.spam(robin, post_disagreed)
          result.reviewable.perform(moderator, :disagree)
        end
        post_agreed = Fabricate(:post, user: user, topic: topic)
        result = PostActionCreator.off_topic(robin, post_agreed)
        result.reviewable.perform(moderator, :agree_and_keep)

        report = Report.find('user_flagging_ratio')

        first = report.data[0]
        expect(first[:username]).to eq("joffrey")
        expect(first[:score]).to eq(2)
        expect(first[:agreed_flags]).to eq(0)
        expect(first[:disagreed_flags]).to eq(2)

        second = report.data[1]
        expect(second[:username]).to eq("robin")
        expect(second[:agreed_flags]).to eq(1)
        expect(second[:disagreed_flags]).to eq(3)
      end
    end
  end

  describe "report_suspicious_logins" do
    let(:joffrey) { Fabricate(:user, username: "joffrey") }
    let(:robin) { Fabricate(:user, username: "robin") }

    context "with data" do
      it "works" do
        SiteSetting.verbose_auth_token_logging = true

        UserAuthToken.log(action: "suspicious", user_id: joffrey.id, created_at: 2.hours.ago)
        UserAuthToken.log(action: "suspicious", user_id: joffrey.id, created_at: 3.hours.ago)
        UserAuthToken.log(action: "suspicious", user_id: robin.id, created_at: 1.hour.ago)

        report = Report.find("suspicious_logins")

        expect(report.data.length).to eq(3)
        expect(report.data[0][:username]).to eq("robin")
        expect(report.data[1][:username]).to eq("joffrey")
        expect(report.data[2][:username]).to eq("joffrey")
      end
    end
  end

  describe "report_staff_logins" do
    let(:joffrey) { Fabricate(:admin, username: "joffrey") }
    let(:robin) { Fabricate(:admin, username: "robin") }
    let(:james) { Fabricate(:user, username: "james") }

    context "with data" do
      it "works" do
        freeze_time DateTime.parse('2017-03-01 12:00')

        ip = [81, 2, 69, 142]

        DiscourseIpInfo.open_db(File.join(Rails.root, 'spec', 'fixtures', 'mmdb'))
        Resolv::DNS.any_instance.stubs(:getname).with(ip.join(".")).returns("ip-#{ip.join("-")}.example.com")

        UserAuthToken.log(action: "generate", user_id: robin.id, client_ip: ip.join("."), created_at: 1.hour.ago)
        UserAuthToken.log(action: "generate", user_id: joffrey.id, client_ip: "1.2.3.4")
        UserAuthToken.log(action: "generate", user_id: joffrey.id, client_ip: ip.join("."), created_at: 2.hours.ago)
        UserAuthToken.log(action: "generate", user_id: james.id)

        report = Report.find("staff_logins")

        expect(report.data.length).to eq(3)
        expect(report.data[0][:username]).to eq("joffrey")

        expect(report.data[1][:username]).to eq("robin")
        expect(report.data[1][:location]).to eq("London, England, United Kingdom")

        expect(report.data[2][:username]).to eq("joffrey")
      end
    end
  end

  describe "report_top_uploads" do
    let(:report) { Report.find("top_uploads") }
    let(:tarek) { Fabricate(:admin, username: "tarek") }
    let(:khalil) { Fabricate(:admin, username: "khalil") }

    context "with data" do
      let!(:tarek_upload) do
        Fabricate(:upload, user: tarek,
                           url: "/uploads/default/original/1X/tarek.jpg",
                           extension: "jpg",
                           original_filename: "tarek.jpg",
                           filesize: 1000)
      end
      let!(:khalil_upload) do
        Fabricate(:upload, user: khalil,
                           url: "/uploads/default/original/1X/khalil.png",
                           extension: "png",
                           original_filename: "khalil.png",
                           filesize: 2000)
      end

      it "works" do
        expect(report.data.length).to eq(2)
        expect_uploads_report_data_to_be_equal(report.data, khalil, khalil_upload)
        expect_uploads_report_data_to_be_equal(report.data, tarek, tarek_upload)
      end
    end

    def expect_uploads_report_data_to_be_equal(data, user, upload)
      row = data.find { |r| r[:author_id] == user.id }
      expect(row[:author_id]).to eq(user.id)
      expect(row[:author_username]).to eq(user.username)
      expect(row[:author_avatar_template]).to eq(User.avatar_template(user.username, user.uploaded_avatar_id))
      expect(row[:filesize]).to eq(upload.filesize)
      expect(row[:extension]).to eq(upload.extension)
      expect(row[:file_url]).to eq(Discourse.store.cdn_url(upload.url))
      expect(row[:file_name]).to eq(upload.original_filename.truncate(25))
    end

    include_examples "no data"
  end

  describe "report_top_ignored_users" do
    let(:report) { Report.find("top_ignored_users") }
    let(:tarek) { Fabricate(:user, username: "tarek") }
    let(:john) { Fabricate(:user, username: "john") }
    let(:matt) { Fabricate(:user, username: "matt") }

    context "with data" do
      before do
        Fabricate(:ignored_user, user: tarek, ignored_user: john)
        Fabricate(:ignored_user, user: tarek, ignored_user: matt)
      end

      it "works" do
        expect(report.data.length).to eq(2)

        expect_ignored_users_report_data_to_be_equal(report.data, john, 1, 0)
        expect_ignored_users_report_data_to_be_equal(report.data, matt, 1, 0)
      end

      context "when muted users exist" do
        before do
          Fabricate(:muted_user, user: tarek, muted_user: john)
          Fabricate(:muted_user, user: tarek, muted_user: matt)
        end

        it "works" do
          expect(report.data.length).to eq(2)
          expect_ignored_users_report_data_to_be_equal(report.data, john, 1, 1)
          expect_ignored_users_report_data_to_be_equal(report.data, matt, 1, 1)
        end
      end
    end

    def expect_ignored_users_report_data_to_be_equal(data, user, ignores, mutes)
      row = data.find { |r| r[:ignored_user_id] == user.id }
      expect(row).to be_present
      expect(row[:ignored_user_id]).to eq(user.id)
      expect(row[:ignored_username]).to eq(user.username)
      expect(row[:ignored_user_avatar_template]).to eq(User.avatar_template(user.username, user.uploaded_avatar_id))
      expect(row[:ignores_count]).to eq(ignores)
      expect(row[:mutes_count]).to eq(mutes)
    end

    include_examples "no data"
  end

  describe "consolidated_page_views" do
    before do
      freeze_time(Time.now.at_midnight)
      Theme.clear_default!
      ApplicationRequest.clear_cache!
    end

    after do
      ApplicationRequest.clear_cache!
    end

    let(:reports) { Report.find('consolidated_page_views') }

    context "with no data" do
      it "works" do
        reports.data.each do |report|
          expect(report[:data]).to be_empty
        end
      end
    end

    context "with data" do
      it "works" do
        3.times { ApplicationRequest.increment!(:page_view_crawler) }
        2.times { ApplicationRequest.increment!(:page_view_logged_in) }
        ApplicationRequest.increment!(:page_view_anon)
        ApplicationRequest.write_cache!

        page_view_crawler_report = reports.data.find { |r| r[:req] == "page_view_crawler" }
        page_view_logged_in_report = reports.data.find { |r| r[:req] == "page_view_logged_in" }
        page_view_anon_report = reports.data.find { |r| r[:req] == "page_view_anon" }

        expect(page_view_crawler_report[:color]).to eql("rgba(228,87,53,0.75)")
        expect(page_view_crawler_report[:data][0][:y]).to eql(3)

        expect(page_view_logged_in_report[:color]).to eql("rgba(0,136,204,1)")
        expect(page_view_logged_in_report[:data][0][:y]).to eql(2)

        expect(page_view_anon_report[:color]).to eql("#40c8ff")
        expect(page_view_anon_report[:data][0][:y]).to eql(1)
      end
    end
  end

  describe "trust_level_growth" do
    before do
      freeze_time(Time.now.at_midnight)
      Theme.clear_default!
    end

    let(:reports) { Report.find('trust_level_growth') }

    context "with no data" do
      it "works" do
        reports.data.each do |report|
          expect(report[:data]).to be_empty
        end
      end
    end

    context "with data" do
      fab!(:gwen) { Fabricate(:user) }
      fab!(:martin) { Fabricate(:user) }

      before do
        UserHistory.create(action: UserHistory.actions[:auto_trust_level_change], target_user_id: gwen.id, new_value: TrustLevel[2], previous_value: 1)
        UserHistory.create(action: UserHistory.actions[:change_trust_level], target_user_id: martin.id, new_value: TrustLevel[4], previous_value: 0)
      end

      it "works" do
        tl1_reached = reports.data.find { |r| r[:req] == "tl1_reached" }
        tl2_reached = reports.data.find { |r| r[:req] == "tl2_reached" }
        tl3_reached = reports.data.find { |r| r[:req] == "tl3_reached" }
        tl4_reached = reports.data.find { |r| r[:req] == "tl4_reached" }

        expect(tl1_reached[:data][0][:y]).to eql(0)
        expect(tl2_reached[:data][0][:y]).to eql(1)
        expect(tl3_reached[:data][0][:y]).to eql(0)
        expect(tl4_reached[:data][0][:y]).to eql(1)
      end
    end
  end
end
