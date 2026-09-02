# frozen_string_literal: true

RSpec.describe TopicsFilter do
  fab!(:user) { Fabricate(:user, username: "username") }
  fab!(:admin)
  fab!(:group)

  describe "#option_info" do
    let(:options) { TopicsFilter.option_info(Guardian.new) }

    it "returns a correct hash with name and description keys for all" do
      expect(options).to be_an(Array)
      expect(options).to all(be_a(Hash))
      expect(options).to all(include(:name, :description))

      # 10 is arbitray, but better than just checking for 1
      expect(options.length).to be > 10
    end

    it "includes nothing about tags when disabled" do
      SiteSetting.tagging_enabled = false

      tag_options = options.find { |o| o[:name].include? "tag" }
      expect(tag_options).to be_nil

      SiteSetting.tagging_enabled = true
      options = TopicsFilter.option_info(Guardian.new)

      tag_options = options.find { |o| o[:name].include? "tag" }
      expect(tag_options).not_to be_nil
    end

    it "advertises the - prefix for the group: option" do
      group_option = options.find { |o| o[:name] == "group:" }

      expect(group_option[:prefixes]).to contain_exactly(
        { name: "-", description: I18n.t("filter.description.exclude_group") },
      )
    end

    it "does not include user-specific options for anonymous users" do
      anon_options = TopicsFilter.option_info(Guardian.new)
      logged_in_options = TopicsFilter.option_info(user.guardian)

      anon_option_names = anon_options.map { |o| o[:name] }.to_set
      logged_in_option_names = logged_in_options.map { |o| o[:name] }.to_set

      user_specific_options = %w[
        in:
        in:pinned
        in:bookmarked
        bookmarked-before:
        bookmarked-after:
        in:watching
        in:tracking
        in:muted
        in:normal
        in:watching_first_post
        in:unseen
      ]

      user_specific_options.each { |option| expect(anon_option_names).not_to include(option) }
      user_specific_options.each { |option| expect(logged_in_option_names).to include(option) }
    end

    it "applies the topics_filter_options modifier for authenticated users" do
      plugin_instance = Plugin::Instance.new
      DiscoursePluginRegistry.register_modifier(
        plugin_instance,
        :topics_filter_options,
      ) do |results, guardian|
        if guardian.authenticated?
          results << {
            name: "custom-filter:",
            description: "A custom filter option from modifier",
            type: "text",
          }
        end
        results
      end

      anon_options = TopicsFilter.option_info(Guardian.new)
      logged_in_options = TopicsFilter.option_info(Guardian.new(user))

      anon_option_names = anon_options.map { |o| o[:name] }
      logged_in_option_names = logged_in_options.map { |o| o[:name] }

      expect(anon_option_names).not_to include("custom-filter:")
      expect(logged_in_option_names).to include("custom-filter:")

      custom_option = logged_in_options.find { |o| o[:name] == "custom-filter:" }
      expect(custom_option).to include(
        name: "custom-filter:",
        description: "A custom filter option from modifier",
        type: "text",
      )
    ensure
      DiscoursePluginRegistry.reset_register!(:modifiers)
    end
  end

  describe "custom filter mappings for in: and status: operators" do
    fab!(:topic)
    fab!(:solved_topic) { Fabricate(:topic, closed: true) }

    describe "custom in: filter" do
      before do
        plugin_instance = Plugin::Instance.new
        DiscoursePluginRegistry.register_modifier(
          plugin_instance,
          :topics_filter_options,
        ) do |results, guardian|
          results << { name: "in:solved", description: "Topics that are solved", type: "text" }
          results
        end

        Plugin::Instance.new.add_filter_custom_filter(
          "in:solved",
          &->(scope, value, guardian) { scope.where(closed: true) }
        )
      end

      after do
        DiscoursePluginRegistry.reset_register!(:custom_filter_mappings)
        DiscoursePluginRegistry.reset_register!(:modifiers)
      end

      it "applies custom in: filter" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new(user))
            .filter_from_query_string("in:solved")
            .pluck(:id),
        ).to contain_exactly(solved_topic.id)
      end

      it "handles comma-separated values with custom filters" do
        TopicUser.change(
          user.id,
          topic.id,
          notification_level: TopicUser.notification_levels[:watching],
        )

        TopicUser.change(
          user.id,
          solved_topic.id,
          notification_level: TopicUser.notification_levels[:watching],
        )

        expect(
          TopicsFilter
            .new(guardian: Guardian.new(user))
            .filter_from_query_string("in:watching,solved")
            .pluck(:id),
        ).to contain_exactly(solved_topic.id)
      end
    end
  end
end
