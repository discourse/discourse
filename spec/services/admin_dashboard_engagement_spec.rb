# frozen_string_literal: true

describe AdminDashboardEngagement do
  describe ".build" do
    before do
      freeze_time(Time.zone.local(2026, 4, 28, 12, 0, 0))
      Discourse.cache.clear
    end

    it "returns a kpis array keyed by report type" do
      result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")

      expect(result[:kpis]).to be_an(Array)
      types = result[:kpis].map { |k| k[:type] }
      expect(types).to include(:dau_mau, :daily_engaged_users, :new_signups)
    end

    it "computes value, previous_value and percent_change for new_signups" do
      Fabricate(:user, created_at: Time.zone.local(2026, 4, 10))
      Fabricate(:user, created_at: Time.zone.local(2026, 4, 15))
      Fabricate(:user, created_at: Time.zone.local(2026, 3, 10))

      result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
      signups = result[:kpis].find { |k| k[:type] == :new_signups }

      expect(signups[:value]).to eq(2)
      expect(signups[:previous_value]).to eq(1)
      expect(signups[:percent_change]).to eq(100.0)
    end

    it "emits report_type and report_query for drill-down" do
      result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
      engaged = result[:kpis].find { |k| k[:type] == :daily_engaged_users }

      expect(engaged[:report_type]).to eq("daily_engaged_users")
      expect(engaged[:report_query]).to eq(start_date: "2026-04-01", end_date: "2026-04-28")
    end

    it "averages daily_engaged_users and reports a decline when daily engagement falls" do
      engaged_now = Fabricate(:user, created_at: Time.zone.local(2026, 1, 1))
      Fabricate(
        :user_action,
        user: engaged_now,
        action_type: UserAction::LIKE,
        created_at: Time.zone.local(2026, 4, 23, 12),
      )
      Fabricate(
        :user_action,
        user: engaged_now,
        action_type: UserAction::LIKE,
        created_at: Time.zone.local(2026, 4, 24, 12),
      )

      4.times do
        engaged_before = Fabricate(:user, created_at: Time.zone.local(2026, 1, 1))
        Fabricate(
          :user_action,
          user: engaged_before,
          action_type: UserAction::LIKE,
          created_at: Time.zone.local(2026, 4, 16, 12),
        )
        Fabricate(
          :user_action,
          user: engaged_before,
          action_type: UserAction::LIKE,
          created_at: Time.zone.local(2026, 4, 17, 12),
        )
      end

      result = described_class.build(start_date: "2026-04-22", end_date: "2026-04-28")
      engaged = result[:kpis].find { |k| k[:type] == :daily_engaged_users }

      expect(engaged[:value]).to eq(1.0)
      expect(engaged[:previous_value]).to eq(4.0)
      expect(engaged[:percent_change]).to eq(-75.0)
      expect(result[:headline][:key]).not_to end_with("healthy_growth")
    end

    it "falls back to a default 30-day window when params are blank" do
      result = described_class.build(start_date: nil, end_date: nil)
      expect(result[:kpis]).to be_an(Array)
      expect(result[:kpis]).not_to be_empty
    end

    it "falls back to defaults when params are unparseable" do
      result = described_class.build(start_date: "garbage", end_date: "also-garbage")
      expect(result[:kpis]).to be_an(Array)
      expect(result[:kpis]).not_to be_empty
    end

    it "ignores unicode garbage in date params" do
      result = described_class.build(start_date: "字字字", end_date: "字字字")
      expect(result[:kpis]).to be_an(Array)
      expect(result[:kpis]).not_to be_empty
    end

    it "skips a KPI when its report errors out" do
      original = Report.method(:find)
      Report.define_singleton_method(:find) do |type, *args, **kwargs|
        if type == "signups"
          r = original.call(type, *args, **kwargs)
          r.error = :timeout
          r
        else
          original.call(type, *args, **kwargs)
        end
      end

      result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
      expect(result[:kpis].map { |k| k[:type] }).not_to include(:new_signups)
    ensure
      Report.define_singleton_method(:find, &original)
    end

    describe "posters" do
      it "includes the posters block with rows and total" do
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        posters = result[:posters]

        expect(posters[:rows].map { |r| r[:type] }).to eq(%i[new_members returning staff])
        expect(posters).to have_key(:total)
      end

      it "honours category visibility when current_user is a moderator" do
        moderator = Fabricate(:moderator)
        returning_poster = Fabricate(:user, created_at: Time.zone.local(2026, 3, 1))
        private_group = Fabricate(:group)
        private_cat = Fabricate(:private_category, group: private_group, read_restricted: true)
        topic = Fabricate(:topic, category: private_cat)
        Fabricate(
          :post,
          user: returning_poster,
          topic: topic,
          created_at: Time.zone.local(2026, 4, 10),
        )

        result =
          described_class.build(
            start_date: "2026-04-01",
            end_date: "2026-04-28",
            current_user: moderator,
          )

        expect(result[:posters][:total]).to eq(0)
      end

      it "lets an admin see posts in restricted categories" do
        admin = Fabricate(:admin)
        returning_poster = Fabricate(:user, created_at: Time.zone.local(2026, 3, 1))
        private_group = Fabricate(:group)
        private_cat = Fabricate(:private_category, group: private_group, read_restricted: true)
        topic = Fabricate(:topic, category: private_cat)
        Fabricate(
          :post,
          user: returning_poster,
          topic: topic,
          created_at: Time.zone.local(2026, 4, 10),
        )

        result =
          described_class.build(
            start_date: "2026-04-01",
            end_date: "2026-04-28",
            current_user: admin,
          )

        expect(result[:posters][:total]).to eq(1)
      end

      it "restricts counted posts to the persisted category selection" do
        selected = Fabricate(:category)
        other = Fabricate(:category)
        poster = Fabricate(:user, created_at: Time.zone.local(2026, 3, 1))
        selected_topic = Fabricate(:topic, category: selected)
        other_topic = Fabricate(:topic, category: other)
        Fabricate(
          :post,
          user: poster,
          topic: selected_topic,
          created_at: Time.zone.local(2026, 4, 10),
        )
        Fabricate(:post, user: poster, topic: other_topic, created_at: Time.zone.local(2026, 4, 10))

        AdminDashboardSectionConfiguration.update_setting(
          section_id: "engagement",
          key: "whos_posting",
          attrs: {
            category_ids: [selected.id],
          },
        )

        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")

        expect(result[:posters][:total]).to eq(1)
      end

      it "omits categories the current user cannot see from the persisted selection" do
        moderator = Fabricate(:moderator)
        visible = Fabricate(:category)
        private_group = Fabricate(:group)
        restricted = Fabricate(:private_category, group: private_group, read_restricted: true)

        AdminDashboardSectionConfiguration.update_setting(
          section_id: "engagement",
          key: "whos_posting",
          attrs: {
            category_ids: [visible.id, restricted.id],
          },
        )

        result =
          described_class.build(
            start_date: "2026-04-01",
            end_date: "2026-04-28",
            current_user: moderator,
          )

        expect(result[:posters][:category_ids]).to contain_exactly(visible.id)
      end
    end

    describe "activity_by_category" do
      it "includes the activity_by_category block with rows and total" do
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        activity = result[:activity_by_category]

        expect(activity).to have_key(:rows)
        expect(activity).to have_key(:total)
      end

      it "honours category visibility when current_user is a moderator" do
        moderator = Fabricate(:moderator)
        private_group = Fabricate(:group)
        private_cat = Fabricate(:private_category, group: private_group, read_restricted: true)
        Fabricate(:topic, category: private_cat, created_at: Time.zone.local(2026, 4, 10))

        result =
          described_class.build(
            start_date: "2026-04-01",
            end_date: "2026-04-28",
            current_user: moderator,
          )

        ids = result[:activity_by_category][:rows].map { |r| r[:category_id] }
        expect(ids).not_to include(private_cat.id)
      end

      it "lets an admin see restricted categories" do
        admin = Fabricate(:admin)
        private_group = Fabricate(:group)
        private_cat = Fabricate(:private_category, group: private_group, read_restricted: true)
        Fabricate(:topic, category: private_cat, created_at: Time.zone.local(2026, 4, 10))

        result =
          described_class.build(
            start_date: "2026-04-01",
            end_date: "2026-04-28",
            current_user: admin,
          )

        ids = result[:activity_by_category][:rows].map { |r| r[:category_id] }
        expect(ids).to include(private_cat.id)
      end

      it "restricts rows to the persisted category selection" do
        selected = Fabricate(:category)
        other = Fabricate(:category)
        Fabricate(:topic, category: selected, created_at: Time.zone.local(2026, 4, 10))
        Fabricate(:topic, category: other, created_at: Time.zone.local(2026, 4, 10))

        AdminDashboardSectionConfiguration.update_setting(
          section_id: "engagement",
          key: "activity_by_category",
          attrs: {
            category_ids: [selected.id],
          },
        )

        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")

        ids = result[:activity_by_category][:rows].map { |r| r[:category_id] }
        expect(ids).to contain_exactly(selected.id)
      end

      it "omits categories the current user cannot see from the persisted selection" do
        moderator = Fabricate(:moderator)
        visible = Fabricate(:category)
        private_group = Fabricate(:group)
        restricted = Fabricate(:private_category, group: private_group, read_restricted: true)

        AdminDashboardSectionConfiguration.update_setting(
          section_id: "engagement",
          key: "activity_by_category",
          attrs: {
            category_ids: [visible.id, restricted.id],
          },
        )

        result =
          described_class.build(
            start_date: "2026-04-01",
            end_date: "2026-04-28",
            current_user: moderator,
          )

        expect(result[:activity_by_category][:category_ids]).to contain_exactly(visible.id)
      end

      it "keeps restricted categories in the persisted selection for an admin" do
        admin = Fabricate(:admin)
        visible = Fabricate(:category)
        private_group = Fabricate(:group)
        restricted = Fabricate(:private_category, group: private_group, read_restricted: true)

        AdminDashboardSectionConfiguration.update_setting(
          section_id: "engagement",
          key: "activity_by_category",
          attrs: {
            category_ids: [visible.id, restricted.id],
          },
        )

        result =
          described_class.build(
            start_date: "2026-04-01",
            end_date: "2026-04-28",
            current_user: admin,
          )

        expect(result[:activity_by_category][:category_ids]).to contain_exactly(
          visible.id,
          restricted.id,
        )
      end
    end

    describe "trust_level_pipeline" do
      it "includes per-TL rows, a trend object, and total_members" do
        Fabricate(:user, trust_level: TrustLevel[1])
        Fabricate(:user, trust_level: TrustLevel[2])

        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        pipeline = result[:trust_level_pipeline]

        expect(pipeline[:rows].length).to eq(5)
        expect(pipeline[:rows].first).to include(
          :trust_level,
          :count,
          :share,
          :promoted_in,
          :demoted_in,
          :signups,
        )
        expect(pipeline[:trend]).to include(:direction, :net)
        expect(pipeline[:total_members]).to be >= 2
      end
    end

    describe "headline" do
      def stub_kpis(signups:, dau: 0, engaged: 0)
        described_class
          .any_instance
          .stubs(:build_kpis)
          .returns(
            [
              { type: :dau_mau, percent_change: dau },
              { type: :new_signups, percent_change: signups },
              { type: :daily_engaged_users, percent_change: engaged },
            ],
          )
      end

      it "returns healthy_growth when every metric is non-negative and at least one is positive" do
        stub_kpis(signups: 12, dau: 3, engaged: 5)
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(result[:headline][:key]).to end_with("healthy_growth")
      end

      it "returns declining when every metric is non-positive and at least one is negative" do
        stub_kpis(signups: -8, dau: -2, engaged: -5)
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(result[:headline][:key]).to end_with("declining")
      end

      it "returns engaged_but_shrinking when stickiness is up but engagement or signups fell" do
        stub_kpis(signups: -5, dau: 2, engaged: -3)
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(result[:headline][:key]).to end_with("engaged_but_shrinking")
      end

      it "returns growing_but_distracted when sign-ups rose but stickiness slipped" do
        stub_kpis(signups: 10, dau: -4, engaged: 0)
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(result[:headline][:key]).to end_with("growing_but_distracted")
      end

      it "returns no_signal when every metric has no change" do
        stub_kpis(signups: 0, dau: 0, engaged: 0)
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(result[:headline][:key]).to end_with("no_signal")
      end

      it "returns mixed when stickiness fell, sign-ups flat, but engagement rose" do
        stub_kpis(signups: 0, dau: -3, engaged: 4)
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(result[:headline][:key]).to end_with("mixed")
      end
    end
  end
end
