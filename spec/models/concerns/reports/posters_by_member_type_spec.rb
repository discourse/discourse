# frozen_string_literal: true

describe Reports::PostersByMemberType do
  before { freeze_time(Time.zone.local(2026, 4, 28, 12, 0, 0)) }

  let(:start_date) { Time.zone.local(2026, 4, 1) }
  let(:end_date) { Time.zone.local(2026, 4, 28).end_of_day }

  def build(filters: {}, current_user: nil)
    Report.find(
      "posters_by_member_type",
      { start_date: start_date, end_date: end_date, filters: filters, current_user: current_user },
    )
  end

  def build_members(group:, filters: {}, current_user: nil)
    Report.find(
      "posters_by_member_type_members",
      {
        start_date: start_date,
        end_date: end_date,
        filters: filters.merge(group: group),
        current_user: current_user,
      },
    )
  end

  def row(report, type)
    report.data.find { |r| r[:type] == type.to_s }
  end

  def group_token(group)
    Report.group_token(group.id)
  end

  it "returns three rows in fixed order by default: new_members, returning, staff" do
    report = build

    types = report.data.map { |r| r[:type] }
    expect(types).to eq(%w[new_members returning staff])
    expect(report.data.map { |r| r[:kind] }).to eq(%w[synthetic synthetic synthetic])
  end

  it "counts staff posts in the staff bucket regardless of join date" do
    admin = Fabricate(:admin, created_at: start_date + 1.day)
    moderator = Fabricate(:moderator, created_at: 6.months.ago)
    Fabricate(:post, user: admin, created_at: start_date + 5.days)
    Fabricate(:post, user: moderator, created_at: start_date + 6.days)

    report = build

    expect(row(report, :staff)[:count]).to eq(2)
    expect(row(report, :new_members)[:count]).to eq(0)
    expect(row(report, :returning)[:count]).to eq(0)
  end

  it "bucketing new members by users who signed up within the period" do
    new_user = Fabricate(:user, created_at: start_date + 2.days)
    Fabricate(:post, user: new_user, created_at: start_date + 3.days)

    report = build

    expect(row(report, :new_members)[:count]).to eq(1)
  end

  it "bucketing returning members by users who signed up before the period" do
    returning_user = Fabricate(:user, created_at: start_date - 30.days)
    Fabricate(:post, user: returning_user, created_at: start_date + 1.day)

    report = build

    expect(row(report, :returning)[:count]).to eq(1)
  end

  it "computes share as a percentage of the period's posts" do
    new_user = Fabricate(:user, created_at: start_date + 1.day)
    returning_user = Fabricate(:user, created_at: start_date - 30.days)
    Fabricate(:post, user: new_user, created_at: start_date + 2.days)
    Fabricate(:post, user: returning_user, created_at: start_date + 3.days)
    Fabricate(:post, user: returning_user, created_at: start_date + 4.days)

    report = build

    expect(row(report, :new_members)[:share]).to eq(33.33)
    expect(row(report, :returning)[:share]).to eq(66.67)
    expect(report.data.sum { |r| r[:share] }).to be_within(0.5).of(100)
  end

  it "excludes deleted posts" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    Fabricate(:post, user: user, created_at: start_date + 1.day, deleted_at: Time.now)

    report = build

    expect(row(report, :returning)[:count]).to eq(0)
  end

  it "excludes posts in deleted topics" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    topic = Fabricate(:topic, deleted_at: Time.now)
    Fabricate(:post, user: user, topic: topic, created_at: start_date + 1.day)

    report = build

    expect(row(report, :returning)[:count]).to eq(0)
  end

  it "excludes posts in private messages" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    pm = Fabricate(:private_message_topic)
    Fabricate(:post, user: user, topic: pm, created_at: start_date + 1.day)

    report = build

    expect(row(report, :returning)[:count]).to eq(0)
  end

  it "excludes posts from system users (id <= 0)" do
    Fabricate(:post, user: Discourse.system_user, created_at: start_date + 1.day)

    report = build

    expect(report.data.sum { |r| r[:count] }).to eq(0)
  end

  it "excludes non-regular post types" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    Fabricate(
      :post,
      user: user,
      created_at: start_date + 1.day,
      post_type: Post.types[:moderator_action],
    )

    report = build

    expect(row(report, :returning)[:count]).to eq(0)
  end

  it "filters by category when the category_ids filter is provided" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    target_category = Fabricate(:category)
    other_category = Fabricate(:category)
    target_topic = Fabricate(:topic, category: target_category)
    other_topic = Fabricate(:topic, category: other_category)
    Fabricate(:post, user: user, topic: target_topic, created_at: start_date + 1.day)
    Fabricate(:post, user: user, topic: other_topic, created_at: start_date + 1.day)

    report = build(filters: { category_ids: [target_category.id] })

    expect(row(report, :returning)[:count]).to eq(1)
  end

  it "filters by the union of multiple categories" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    first_category = Fabricate(:category)
    second_category = Fabricate(:category)
    other_category = Fabricate(:category)
    first_topic = Fabricate(:topic, category: first_category)
    second_topic = Fabricate(:topic, category: second_category)
    other_topic = Fabricate(:topic, category: other_category)
    Fabricate(:post, user: user, topic: first_topic, created_at: start_date + 1.day)
    Fabricate(:post, user: user, topic: second_topic, created_at: start_date + 1.day)
    Fabricate(:post, user: user, topic: other_topic, created_at: start_date + 1.day)

    report = build(filters: { category_ids: [first_category.id, second_category.id] })

    expect(row(report, :returning)[:count]).to eq(2)
  end

  it "accepts a comma-separated string of category ids" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    target_category = Fabricate(:category)
    other_category = Fabricate(:category)
    target_topic = Fabricate(:topic, category: target_category)
    other_topic = Fabricate(:topic, category: other_category)
    Fabricate(:post, user: user, topic: target_topic, created_at: start_date + 1.day)
    Fabricate(:post, user: user, topic: other_topic, created_at: start_date + 1.day)

    report = build(filters: { category_ids: target_category.id.to_s })

    expect(row(report, :returning)[:count]).to eq(1)
  end

  it "returns zero counts when a requested category filter resolves to no valid ids" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    topic = Fabricate(:topic, category: Fabricate(:category))
    Fabricate(:post, user: user, topic: topic, created_at: start_date + 1.day)

    report = build(filters: { category_ids: "foo,bar" })

    expect(report.total).to eq(0)
    expect(report.data.sum { |r| r[:count] }).to eq(0)
  end

  it "strips category ids that don't correspond to an existing category" do
    nonexistent_id = Category.unscoped.maximum(:id).to_i + 1

    report = build(filters: { category_ids: [nonexistent_id] })

    expect(report.available_filters["category_ids"][:default]).to eq([])
  end

  it "keeps only the existing ids when the filter mixes real and nonexistent categories" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    target_category = Fabricate(:category)
    target_topic = Fabricate(:topic, category: target_category)
    Fabricate(:post, user: user, topic: target_topic, created_at: start_date + 1.day)
    nonexistent_id = Category.unscoped.maximum(:id).to_i + 1

    report = build(filters: { category_ids: [target_category.id, nonexistent_id] })

    expect(report.available_filters["category_ids"][:default]).to eq([target_category.id])
    expect(row(report, :returning)[:count]).to eq(1)
  end

  it "preserves the requested order of the category ids" do
    first = Fabricate(:category)
    second = Fabricate(:category)
    third = Fabricate(:category)

    report = build(filters: { category_ids: [third.id, first.id, second.id] })

    expect(report.available_filters["category_ids"][:default]).to eq(
      [third.id, first.id, second.id],
    )
  end

  it "caps the requested category ids at MAX_CATEGORY_IDS" do
    cats = Array.new(60) { Fabricate(:category) }

    report = build(filters: { category_ids: cats.map(&:id).join(",") })

    expect(report.available_filters["category_ids"][:default].length).to eq(
      Reports::PostersByMemberType::MAX_CATEGORY_IDS,
    )
  end

  it "renders a unicode category name without errors" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    cat = Fabricate(:category, name: "字テスト")
    topic = Fabricate(:topic, category: cat)
    Fabricate(:post, user: user, topic: topic, created_at: start_date + 1.day)

    expect { build(filters: { category_ids: [cat.id] }) }.not_to raise_error
  end

  describe "secured categories" do
    fab!(:moderator)
    fab!(:admin)
    fab!(:private_group, :group)

    it "excludes posts in restricted categories from a moderator's unfiltered total" do
      private_category = Fabricate(:private_category, group: private_group, read_restricted: true)
      poster = Fabricate(:user, created_at: start_date - 30.days)
      topic = Fabricate(:topic, category: private_category)
      Fabricate(:post, user: poster, topic: topic, created_at: start_date + 1.day)

      report = build(current_user: moderator)

      expect(report.data.sum { |r| r[:count] }).to eq(0)
    end

    it "returns zero when a moderator filters by a category they cannot access" do
      private_category = Fabricate(:private_category, group: private_group, read_restricted: true)
      poster = Fabricate(:user, created_at: start_date - 30.days)
      topic = Fabricate(:topic, category: private_category)
      Fabricate(:post, user: poster, topic: topic, created_at: start_date + 1.day)

      report = build(filters: { category_ids: [private_category.id] }, current_user: moderator)

      expect(row(report, :returning)[:count]).to eq(0)
    end

    it "lets an admin see posts in restricted categories" do
      private_category = Fabricate(:private_category, group: private_group, read_restricted: true)
      poster = Fabricate(:user, created_at: start_date - 30.days)
      topic = Fabricate(:topic, category: private_category)
      Fabricate(:post, user: poster, topic: topic, created_at: start_date + 1.day)

      report = build(filters: { category_ids: [private_category.id] }, current_user: admin)

      expect(row(report, :returning)[:count]).to eq(1)
    end
  end

  describe "groups" do
    fab!(:admin)

    it "includes a real group's posts alongside the synthetic buckets, in the requested order" do
      group = Fabricate(:group)
      member = Fabricate(:user, created_at: start_date - 30.days)
      Fabricate(:group_user, group: group, user: member)
      Fabricate(:post, user: member, created_at: start_date + 1.day)

      report =
        build(filters: { groups: "staff,#{group_token(group)},new_members" }, current_user: admin)

      expect(report.data.map { |r| r[:type] }).to eq(%W[staff #{group_token(group)} new_members])
      group_row = row(report, group_token(group))
      expect(group_row[:kind]).to eq("group")
      expect(group_row[:name]).to eq(group.name)
      expect(group_row[:count]).to eq(1)
    end

    it "prefers a group's full name over its internal name" do
      group = Fabricate(:group, name: "customer_support", full_name: "Customer support")

      report = build(filters: { groups: group_token(group) }, current_user: admin)

      expect(row(report, group_token(group))[:name]).to eq("Customer support")
    end

    it "allows overlap between a group and a synthetic bucket without shares summing to 100" do
      group = Fabricate(:group)
      member = Fabricate(:user, created_at: start_date - 30.days)
      Fabricate(:group_user, group: group, user: member)
      Fabricate(:post, user: member, created_at: start_date + 1.day)
      Fabricate(
        :post,
        user: Fabricate(:user, created_at: start_date - 30.days),
        created_at: start_date + 1.day,
      )

      report = build(filters: { groups: "returning,#{group_token(group)}" }, current_user: admin)

      returning_row = row(report, :returning)
      group_row = row(report, group_token(group))
      expect(returning_row[:count]).to eq(2)
      expect(group_row[:count]).to eq(1)
      expect(returning_row[:share]).to eq(100.0)
      expect(group_row[:share]).to eq(50.0)
    end

    it "computes the grand total across all posts in the period, independent of which groups are selected" do
      group = Fabricate(:group)
      member = Fabricate(:user, created_at: start_date - 30.days)
      Fabricate(:group_user, group: group, user: member)
      Fabricate(:post, user: member, created_at: start_date + 1.day)
      Fabricate(:post, user: Fabricate(:admin), created_at: start_date + 1.day)

      report = build(filters: { groups: group_token(group) }, current_user: admin)

      expect(report.total).to eq(2)
      expect(row(report, group_token(group))[:count]).to eq(1)
    end

    it "falls back to the default 3 synthetic groups when nothing valid is requested" do
      nonexistent_token = Report.group_token(Group.unscoped.maximum(:id).to_i + 1)

      report = build(filters: { groups: "bogus,#{nonexistent_token}" }, current_user: admin)

      expect(report.data.map { |r| r[:type] }).to eq(%w[new_members returning staff])
    end

    it "drops duplicate and invalid tokens, and caps at MAX_GROUPS" do
      groups = Array.new(12) { Fabricate(:group) }
      tokens = (%w[new_members new_members] + groups.map { |g| group_token(g) }).join(",")

      report = build(filters: { groups: tokens }, current_user: admin)

      expect(report.data.length).to eq(Reports::PostersByMemberType::MAX_GROUPS)
      expect(report.data.map { |r| r[:type] }.uniq.length).to eq(report.data.length)
    end

    it "rejects the real staff automatic group and other reserved auto-groups" do
      staff_group_token = Report.group_token(Group::AUTO_GROUPS[:staff])
      everyone_token = Report.group_token(Group::AUTO_GROUPS[:everyone])

      report =
        build(
          filters: {
            groups: "#{staff_group_token},#{everyone_token},staff",
          },
          current_user: admin,
        )

      expect(report.data.map { |r| r[:type] }).to eq(%w[staff])
    end

    it "drops a group id that doesn't exist" do
      nonexistent_token = Report.group_token(Group.unscoped.maximum(:id).to_i + 1)

      report = build(filters: { groups: "staff,#{nonexistent_token}" }, current_user: admin)

      expect(report.data.map { |r| r[:type] }).to eq(%w[staff])
    end

    it "drops a group the current user (a non-staff moderator scope) cannot see" do
      moderator = Fabricate(:moderator)
      hidden_group = Fabricate(:group, visibility_level: Group.visibility_levels[:staff])

      report =
        build(
          filters: {
            groups: "staff,#{group_token(hidden_group)}",
          },
          current_user: Fabricate(:user),
        )

      expect(report.data.map { |r| r[:type] }).to eq(%w[staff])
    end

    it "drops a group whose members are hidden from the current user, even when the group itself is visible" do
      group = Fabricate(:group, members_visibility_level: Group.visibility_levels[:owners])
      member = Fabricate(:user, created_at: start_date - 30.days)
      Fabricate(:group_user, group: group, user: member)
      Fabricate(:post, user: member, created_at: start_date + 1.day)

      report =
        build(filters: { groups: "staff,#{group_token(group)}" }, current_user: Fabricate(:user))

      expect(report.data.map { |r| r[:type] }).to eq(%w[staff])
    end

    it "counts every requested group's posts in a single grouped query, not one query per group" do
      groups = Array.new(5) { Fabricate(:group) }
      groups.each do |group|
        member = Fabricate(:user, created_at: start_date - 30.days)
        Fabricate(:group_user, group: group, user: member)
        Fabricate(:post, user: member, created_at: start_date + 1.day)
      end
      tokens = groups.map { |g| group_token(g) }.join(",")

      queries = track_sql_queries { build(filters: { groups: tokens }, current_user: admin) }
      group_scan_queries = queries.select { |sql| sql.include?("group_users") }

      expect(group_scan_queries.length).to eq(1)
    end
  end

  describe ".report_posters_by_member_type_members" do
    fab!(:admin)

    it "returns per-user rows for a synthetic bucket, ordered by count desc" do
      top_poster = Fabricate(:user, created_at: start_date - 30.days, username: "topposter")
      other_poster = Fabricate(:user, created_at: start_date - 30.days, username: "otherposter")
      2.times { |i| Fabricate(:post, user: top_poster, created_at: start_date + i.days) }
      Fabricate(:post, user: other_poster, created_at: start_date + 1.day)

      report = build_members(group: "returning", current_user: admin)

      expect(report.error).to be_nil
      expect(report.total).to eq(3)
      expect(report.data.map { |r| r[:username] }).to eq(%w[topposter otherposter])
      expect(report.data.first[:count]).to eq(2)
      expect(report.data.first[:share]).to eq(66.67)
    end

    it "computes the share denominator from every poster, not just the displayed rows" do
      stub_const(Reports::PostersByMemberType, :MAX_MEMBER_ROWS, 2) do
        posters = Array.new(3) { Fabricate(:user, created_at: start_date - 30.days) }
        posters.each { |user| Fabricate(:post, user: user, created_at: start_date + 1.day) }

        report = build_members(group: "returning", current_user: admin)

        expect(report.data.length).to eq(2)
        expect(report.total).to eq(3)
        expect(report.data.sum { |r| r[:share] }).to be < 100
      end
    end

    it "returns per-user rows for a real group, scoped to that group's members only" do
      group = Fabricate(:group)
      member = Fabricate(:user, created_at: start_date - 30.days)
      non_member = Fabricate(:user, created_at: start_date - 30.days)
      Fabricate(:group_user, group: group, user: member)
      Fabricate(:post, user: member, created_at: start_date + 1.day)
      Fabricate(:post, user: non_member, created_at: start_date + 1.day)

      report = build_members(group: group_token(group), current_user: admin)

      expect(report.data.map { |r| r[:user_id] }).to eq([member.id])
      expect(report.total).to eq(1)
    end

    it "returns :not_found for an unparseable group token" do
      report = build_members(group: "not-a-real-token", current_user: admin)

      expect(report.error).to eq(:not_found)
    end

    it "returns :not_found when the guardian cannot see the group's members" do
      private_group = Fabricate(:group, members_visibility_level: Group.visibility_levels[:owners])
      member = Fabricate(:user, created_at: start_date - 30.days)
      Fabricate(:group_user, group: private_group, user: member)
      Fabricate(:post, user: member, created_at: start_date + 1.day)

      report = build_members(group: group_token(private_group), current_user: Fabricate(:user))

      expect(report.error).to eq(:not_found)
    end

    it "lets a staff user see members of a staff-visible group" do
      staff_visible_group =
        Fabricate(:group, members_visibility_level: Group.visibility_levels[:staff])
      member = Fabricate(:user, created_at: start_date - 30.days)
      Fabricate(:group_user, group: staff_visible_group, user: member)
      Fabricate(:post, user: member, created_at: start_date + 1.day)

      report =
        build_members(group: group_token(staff_visible_group), current_user: Fabricate(:moderator))

      expect(report.error).to be_nil
      expect(report.data.map { |r| r[:user_id] }).to eq([member.id])
    end

    it "respects the category filter" do
      target_category = Fabricate(:category)
      other_category = Fabricate(:category)
      user = Fabricate(:user, created_at: start_date - 30.days)
      Fabricate(
        :post,
        user: user,
        topic: Fabricate(:topic, category: target_category),
        created_at: start_date + 1.day,
      )
      Fabricate(
        :post,
        user: user,
        topic: Fabricate(:topic, category: other_category),
        created_at: start_date + 1.day,
      )

      report =
        build_members(
          group: "returning",
          filters: {
            category_ids: [target_category.id],
          },
          current_user: admin,
        )

      expect(report.total).to eq(1)
    end
  end
end
