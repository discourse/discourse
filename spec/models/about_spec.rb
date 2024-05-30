# frozen_string_literal: true

RSpec.describe About do
  describe "stats cache" do
    include_examples "stats cacheable"
  end

  def register_stat(name, stats_block)
    DiscoursePluginRegistry.register_stat(
      Stat.new(name, show_in_ui: true, expose_via_api: true, &stats_block),
      stub(enabled?: true),
    )
  end

  after { DiscoursePluginRegistry.reset! }

  describe "#stats" do
    it "adds plugin stats to the output" do
      stats = { :last_day => 1, "7_days" => 10, "30_days" => 100, :count => 1000 }
      register_stat("some_group", Proc.new { stats })
      expect(described_class.new.stats.with_indifferent_access).to match(
        hash_including(
          some_group_last_day: 1,
          some_group_7_days: 10,
          some_group_30_days: 100,
          some_group_count: 1000,
        ),
      )
    end

    it "does not add plugin stats to the output if they are missing one of the required keys" do
      stats = { "7_days" => 10, "30_days" => 100, :count => 1000 }
      register_stat("some_group", Proc.new { stats })
      expect(described_class.new.stats).not_to match(
        hash_including(
          some_group_last_day: 1,
          some_group_7_days: 10,
          some_group_30_days: 100,
          some_group_count: 1000,
        ),
      )
    end

    it "does not error if any of the plugin stat blocks throw an error and still adds the non-errored stats to output" do
      stats = { :last_day => 1, "7_days" => 10, "30_days" => 100, :count => 1000 }
      register_stat("some_group", Proc.new { stats })
      register_stat("other_group", Proc.new { raise StandardError })
      expect(described_class.new.stats.with_indifferent_access).to match(
        hash_including(
          some_group_last_day: 1,
          some_group_7_days: 10,
          some_group_30_days: 100,
          some_group_count: 1000,
        ),
      )
      expect { described_class.new.stats.with_indifferent_access }.not_to raise_error
    end
  end

  describe "#category_moderators" do
    let(:user) { Fabricate(:user) }
    let(:public_cat_moderator) { Fabricate(:user, last_seen_at: 1.month.ago) }
    let(:private_cat_moderator) { Fabricate(:user, last_seen_at: 2.month.ago) }
    let(:common_moderator) { Fabricate(:user, last_seen_at: 3.month.ago) }
    let(:common_moderator_2) { Fabricate(:user, last_seen_at: 4.month.ago) }

    let(:public_group) do
      group = Fabricate(:public_group)
      group.add(public_cat_moderator)
      group.add(common_moderator)
      group.add(common_moderator_2)
      group
    end

    let(:private_group) do
      group = Fabricate(:group)
      group.add(private_cat_moderator)
      group.add(common_moderator)
      group.add(common_moderator_2)
      group
    end

    let!(:public_cat) { Fabricate(:category, reviewable_by_group: public_group) }
    let!(:private_cat) do
      Fabricate(:private_category, group: private_group, reviewable_by_group: private_group)
    end

    it "lists moderators of the category that the current user can see" do
      results = About.new(private_cat_moderator).category_moderators
      expect(results.map(&:category).map(&:id)).to contain_exactly(public_cat.id, private_cat.id)
      expect(results.map(&:moderators).flatten.map(&:id).uniq).to contain_exactly(
        public_cat_moderator.id,
        common_moderator.id,
        common_moderator_2.id,
        private_cat_moderator.id,
      )

      [public_cat_moderator, user, nil].each do |u|
        results = About.new(u).category_moderators
        expect(results.map(&:category).map(&:id)).to contain_exactly(public_cat.id)
        expect(results.map(&:moderators).flatten.map(&:id)).to eq(
          [public_cat_moderator.id, common_moderator.id, common_moderator_2.id],
        )
      end
    end

    it "limit category moderators when there are too many for perf reasons" do
      about = About.new(private_cat_moderator)
      about.category_mods_limit = 4
      results = about.category_moderators
      expect(results.size).to eq(2)
      results.each { |res| expect(res.moderators.size).to eq(2) }
    end
  end

  describe "#admins" do
    fab!(:admin_mark) { Fabricate(:admin, name: "mark") }
    fab!(:admin_matt) { Fabricate(:admin, name: "matt") }
    fab!(:admin_kate) { Fabricate(:admin, name: "kate") }

    context "with about_admins plugin modifier registered" do
      let(:modifier_block) { Proc.new { |admins| admins.select { |admin| admin.name != "mark" } } }

      it "Applies registered modifiers (filtering out admins in this case)" do
        plugin_instance = Plugin::Instance.new
        plugin_instance.register_modifier(:about_admins, &modifier_block)
        expect(About.new(Fabricate(:user)).admins).to match_array([admin_matt, admin_kate])
      ensure
        DiscoursePluginRegistry.unregister_modifier(plugin_instance, :about_admins, &modifier_block)
      end
    end
  end
end
