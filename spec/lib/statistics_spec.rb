# frozen_string_literal: true

RSpec.describe Statistics do
  def create_page_views_and_user_visit_records(date, users)
    freeze_time(date - 50.minutes) do
      2.times { ApplicationRequest.increment!(:page_view_anon_browser) }
      ApplicationRequest.increment!(:page_view_logged_in_browser)
    end

    freeze_time(date - 3.days) do
      ApplicationRequest.increment!(:page_view_anon_browser)
      5.times { ApplicationRequest.increment!(:page_view_logged_in_browser) }
    end

    freeze_time(date - 6.days) do
      3.times { ApplicationRequest.increment!(:page_view_anon_browser) }
      4.times { ApplicationRequest.increment!(:page_view_logged_in_browser) }
    end

    freeze_time(date - 8.days) do
      ApplicationRequest.increment!(:page_view_anon_browser)
      ApplicationRequest.increment!(:page_view_logged_in_browser)
    end

    freeze_time(date - 15.days) do
      4.times { ApplicationRequest.increment!(:page_view_anon_browser) }
      3.times { ApplicationRequest.increment!(:page_view_logged_in_browser) }
    end

    freeze_time(date - 31.days) do
      ApplicationRequest.increment!(:page_view_anon_browser)
      ApplicationRequest.increment!(:page_view_logged_in_browser)
    end

    UserVisit.create!(user_id: users[0].id, visited_at: date - 50.minute)

    UserVisit.create!(user_id: users[0].id, visited_at: date - 36.hours)
    UserVisit.create!(user_id: users[1].id, visited_at: date - 2.day)
    UserVisit.create!(user_id: users[0].id, visited_at: date - 4.days)
    UserVisit.create!(user_id: users[2].id, visited_at: date - 6.days)
    UserVisit.create!(user_id: users[3].id, visited_at: date - 3.days)
    UserVisit.create!(user_id: users[3].id, visited_at: date - 5.days)
    UserVisit.create!(user_id: users[1].id, visited_at: date - 66.hours)

    UserVisit.create!(user_id: users[2].id, visited_at: date - 8.days)
    UserVisit.create!(user_id: users[3].id, visited_at: date - 13.days)
    UserVisit.create!(user_id: users[0].id, visited_at: date - 24.days)
    UserVisit.create!(user_id: users[4].id, visited_at: date - 19.days)

    UserVisit.create!(user_id: users[2].id, visited_at: date - 31.days)
  end

  fab!(:users) { Fabricate.times(5, :user) }
  let(:date) { DateTime.parse("2024-03-01 13:00") }

  describe ".users" do
    before { User.real.destroy_all }

    it "doesn't count inactive, silenced, or suspended users" do
      res = described_class.users
      expect(res[:last_day]).to eq(0)
      expect(res[:"7_days"]).to eq(0)
      expect(res[:"30_days"]).to eq(0)
      expect(res[:count]).to eq(0)

      user = Fabricate(:user, active: true)
      user2 = Fabricate(:user, active: true)
      user3 = Fabricate(:user, active: true)

      res = described_class.users
      expect(res[:last_day]).to eq(3)
      expect(res[:"7_days"]).to eq(3)
      expect(res[:"30_days"]).to eq(3)
      expect(res[:count]).to eq(3)

      user.update!(active: false)

      res = described_class.users
      expect(res[:last_day]).to eq(2)
      expect(res[:"7_days"]).to eq(2)
      expect(res[:"30_days"]).to eq(2)
      expect(res[:count]).to eq(2)

      user2.update!(silenced_till: 1.month.from_now)

      res = described_class.users
      expect(res[:last_day]).to eq(1)
      expect(res[:"7_days"]).to eq(1)
      expect(res[:"30_days"]).to eq(1)
      expect(res[:count]).to eq(1)

      user3.update!(suspended_till: 1.month.from_now)

      res = described_class.users
      expect(res[:last_day]).to eq(0)
      expect(res[:"7_days"]).to eq(0)
      expect(res[:"30_days"]).to eq(0)
      expect(res[:count]).to eq(0)
    end

    it "doesn't include unapproved users if must_approve_users setting is true" do
      SiteSetting.must_approve_users = false

      user = Fabricate(:user, active: true, approved: false)

      res = described_class.users
      expect(res[:last_day]).to eq(1)
      expect(res[:"7_days"]).to eq(1)
      expect(res[:"30_days"]).to eq(1)
      expect(res[:count]).to eq(1)

      SiteSetting.must_approve_users = true
      # changing the site setting approves all existing users
      # flip this one back to unapproved
      user.reload.update!(approved: false)

      res = described_class.users
      expect(res[:last_day]).to eq(0)
      expect(res[:"7_days"]).to eq(0)
      expect(res[:"30_days"]).to eq(0)
      expect(res[:count]).to eq(0)

      user.update!(approved: true)

      res = described_class.users
      expect(res[:last_day]).to eq(1)
      expect(res[:"7_days"]).to eq(1)
      expect(res[:"30_days"]).to eq(1)
      expect(res[:count]).to eq(1)
    end

    it "counts users in the time windows they were created in" do
      res = described_class.users
      expect(res[:last_day]).to eq(0)
      expect(res[:"7_days"]).to eq(0)
      expect(res[:"30_days"]).to eq(0)
      expect(res[:count]).to eq(0)

      Fabricate(:user, active: true, created_at: 31.days.ago)

      res = described_class.users
      expect(res[:last_day]).to eq(0)
      expect(res[:"7_days"]).to eq(0)
      expect(res[:"30_days"]).to eq(0)
      expect(res[:count]).to eq(1)

      Fabricate(:user, active: true, created_at: 28.days.ago)

      res = described_class.users
      expect(res[:last_day]).to eq(0)
      expect(res[:"7_days"]).to eq(0)
      expect(res[:"30_days"]).to eq(1)
      expect(res[:count]).to eq(2)

      Fabricate(:user, active: true, created_at: 6.days.ago)

      res = described_class.users
      expect(res[:last_day]).to eq(0)
      expect(res[:"7_days"]).to eq(1)
      expect(res[:"30_days"]).to eq(2)
      expect(res[:count]).to eq(3)

      Fabricate(:user, active: true, created_at: 6.hours.ago)

      res = described_class.users
      expect(res[:last_day]).to eq(1)
      expect(res[:"7_days"]).to eq(2)
      expect(res[:"30_days"]).to eq(3)
      expect(res[:count]).to eq(4)
    end
  end

  describe ".participating_users" do
    it "returns no participating users by default" do
      pu = described_class.participating_users
      expect(pu[:last_day]).to eq(0)
      expect(pu[:"7_days"]).to eq(0)
      expect(pu[:"30_days"]).to eq(0)
    end

    it "returns users who have reacted to a post" do
      Fabricate(:user_action, action_type: UserAction::LIKE)
      expect(described_class.participating_users[:last_day]).to eq(1)
    end

    it "returns users who have created a new topic" do
      Fabricate(:user_action, action_type: UserAction::NEW_TOPIC)
      expect(described_class.participating_users[:last_day]).to eq(1)
    end

    it "returns users who have replied to a post" do
      Fabricate(:user_action, action_type: UserAction::REPLY)
      expect(described_class.participating_users[:last_day]).to eq(1)
    end

    it "returns users who have created a new PM" do
      Fabricate(:user_action, action_type: UserAction::NEW_PRIVATE_MESSAGE)
      expect(described_class.participating_users[:last_day]).to eq(1)
    end

    it "doesn't count bots" do
      Fabricate(:user_action, action_type: UserAction::LIKE, user: Discourse.system_user)
      expect(described_class.participating_users[:last_day]).to eq(0)
    end
  end

  describe ".visitors" do
    before do
      ApplicationRequest.enable
      create_page_views_and_user_visit_records(date, users)
    end

    after { ApplicationRequest.disable }

    it "estimates the number of visitors for each of the previous 1 day, 7 days and 30 days periods" do
      freeze_time(date) do
        visitors = described_class.visitors

        # anon page views: 2
        # logged-in page views: 1
        # logged-in visitors: 1
        # we can estimate the number of unique anon visitors by dividing the
        # number of anon page views by the average number of logged-in page
        # views per logged-in visitor.
        # in this case, the estimated number of anon visitors is 2 / (1 / 1) = 2.
        # total visitors = logged-in visitors (1) + estimated anon visitors (2) = 3
        expect(visitors[:last_day]).to eq(3)

        # anon page views: 6
        # logged-in page views: 10
        # logged-in visitors: 4
        # we can estimate the number of unique anon visitors by dividing the
        # number of anon page views by the average number of logged-in page
        # views per logged-in visitor.
        # in this case, the estimated number of anon visitors is 6 / (10 / 4) ~= 2.
        # total visitors = logged-in visitors (4) + estimated anon visitors (2) = 6
        expect(visitors[:"7_days"]).to eq(6)

        # anon page views: 11
        # logged-in page views: 14
        # logged-in visitors: 5
        # we can estimate the number of unique anon visitors by dividing the
        # number of anon page views by the average number of logged-in page
        # views per logged-in visitor.
        # in this case, the estimated number of anon visitors is 11 / (14 / 5) ~= 4.
        # total visitors = logged-in visitors (5) + estimated anon visitors (4) = 9
        expect(visitors[:"30_days"]).to eq(9)
      end
    end

    it "is the same as the number of anon page views when there are no logged in visitors" do
      freeze_time(date) do
        UserVisit.delete_all

        visitors = described_class.visitors

        expect(visitors[:last_day]).to eq(2)
        expect(visitors[:"7_days"]).to eq(6)
        expect(visitors[:"30_days"]).to eq(11)
      end
    end
  end

  describe ".eu_visitors" do
    before do
      ApplicationRequest.enable
      create_page_views_and_user_visit_records(date, users)

      users[0].update!(ip_address: IPAddr.new("60.23.1.42"))
      users[1].update!(ip_address: IPAddr.new("90.19.255.63"))
      users[2].update!(ip_address: IPAddr.new("8.33.134.244"))
      users[3].update!(ip_address: IPAddr.new("2.74.0.98"))
      users[4].update!(ip_address: IPAddr.new("88.82.3.101"))

      # EU IP addresses
      DiscourseIpInfo.stubs(:get).with("60.23.1.42").returns({ country_code: "FR" }) # users[0]
      DiscourseIpInfo.stubs(:get).with("2.74.0.98").returns({ country_code: "NL" }) # users[3]
      DiscourseIpInfo.stubs(:get).with("88.82.3.101").returns({ country_code: "DE" }) # users[4]

      # non-EU IP addresses
      DiscourseIpInfo.stubs(:get).with("90.19.255.63").returns({ country_code: "US" }) # users[1]
      DiscourseIpInfo.stubs(:get).with("8.33.134.244").returns({ country_code: "SA" }) # users[2]
    end

    after { ApplicationRequest.disable }

    it "estimates the number of EU visitors for each of the previous 1 day, 7 days and 30 days periods" do
      freeze_time(date) do
        eu_visitors = described_class.eu_visitors

        # anon page views: 2
        # logged-in page views: 1
        # logged-in visitors: 1
        # EU logged-in visitors: 1 (users[0])
        # we can estimate the number of unique EU anon visitors by dividing the
        # number of anon page views by the average number of logged-in page
        # views per logged-in visitor, then multiplying the result by the ratio
        # of EU logged-in visitors to all logged-in visitors.
        # in this case, the estimated number of EU anon visitors is 2 / (1 / 1) * (1 / 1) = 2
        # total EU visitors = EU logged-in visitors (1) + estimated EU anon visitors (2) = 3
        expect(eu_visitors[:last_day]).to eq(3)

        # anon page views: 6
        # logged-in page views: 10
        # logged-in visitors: 4
        # EU logged-in visitors: 2 (users[0], users[3])
        # we can estimate the number of unique EU anon visitors by dividing the
        # number of anon page views by the average number of logged-in page
        # views per logged-in visitor, then multiplying the result by the ratio
        # of EU logged-in visitors to all logged-in visitors.
        # in this case, the estimated number of EU anon visitors is 6 / (10 / 4) * (2 / 4) ~= 1
        # total EU visitors = EU logged-in visitors (2) + estimated EU anon visitors (1) = 3
        expect(eu_visitors[:"7_days"]).to eq(3)

        # anon page views: 11
        # logged-in page views: 14
        # logged-in visitors: 5
        # EU logged-in visitors: 3 (users[0], users[3], users[4])
        # we can estimate the number of unique EU anon visitors by dividing the
        # number of anon page views by the average number of logged-in page
        # views per logged-in visitor, then multiplying the result by the ratio
        # of EU logged-in visitors to all logged-in visitors.
        # in this case, the estimated number of EU anon visitors is 11 / (14 / 5) * (3 / 5) ~= 1
        # total EU visitors = EU logged-in visitors (3) + estimated EU anon visitors (2) = 5
        expect(eu_visitors[:"30_days"]).to eq(5)
      end
    end

    it "returns 0 for EU visitors when there are no logged-in users" do
      freeze_time(date) do
        UserVisit.delete_all

        eu_visitors = described_class.eu_visitors
        expect(eu_visitors[:last_day]).to eq(0)
        expect(eu_visitors[:"7_days"]).to eq(0)
        expect(eu_visitors[:"30_days"]).to eq(0)
      end
    end
  end
end
