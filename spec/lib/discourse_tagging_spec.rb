# encoding: UTF-8
# frozen_string_literal: true

require "discourse_tagging"

# More tests are found in the category_tag_spec integration specs

RSpec.describe DiscourseTagging do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  let(:admin_guardian) { Guardian.new(admin) }
  let(:guardian) { Guardian.new(user) }

  fab!(:tag1) { Fabricate(:tag, name: "fun") }
  fab!(:tag2) { Fabricate(:tag, name: "fun2") }
  fab!(:tag3) { Fabricate(:tag, name: "Fun3") }

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.min_trust_to_create_tag = 0
    SiteSetting.min_trust_level_to_tag_topics = 0
  end

  describe "visible_tags" do
    fab!(:tag4) { Fabricate(:tag, name: "fun4") }

    fab!(:user2) { Fabricate(:user) }
    let(:guardian2) { Guardian.new(user2) }

    fab!(:group) { Fabricate(:group, name: "my-group") }
    fab!(:group_user) { Fabricate(:group_user, group: group, user: user) }

    fab!(:tag_group2) do
      Fabricate(:tag_group, permissions: { "everyone" => 1 }, tag_names: [tag2.name])
    end

    fab!(:tag_group3) do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag3.name])
    end

    fab!(:tag_group4) do
      Fabricate(:tag_group, permissions: { "my-group" => 1 }, tag_names: [tag4.name])
    end

    context "for admin" do
      it "includes tags with no tag_groups" do
        expect(DiscourseTagging.visible_tags(admin_guardian)).to include(tag1)
      end

      it "includes tags with tags visible to everyone" do
        expect(DiscourseTagging.visible_tags(admin_guardian)).to include(tag2)
      end

      it "includes tags which are visible to staff" do
        expect(DiscourseTagging.visible_tags(admin_guardian)).to include(tag3)
      end

      it "includes tags which are visible to members of certain groups" do
        expect(DiscourseTagging.visible_tags(admin_guardian)).to include(tag4)
      end
    end

    context "for users in a group" do
      it "includes tags with no tag_groups" do
        expect(DiscourseTagging.visible_tags(guardian)).to include(tag1)
      end

      it "includes tags with tags visible to everyone" do
        expect(DiscourseTagging.visible_tags(guardian)).to include(tag2)
      end

      it "does not include tags which are only visible to staff" do
        expect(DiscourseTagging.visible_tags(guardian)).not_to include(tag3)
      end

      it "includes tags which are visible to members of the group" do
        expect(DiscourseTagging.visible_tags(guardian)).to include(tag4)
      end
    end

    context "for other users" do
      it "includes tags with no tag_groups" do
        expect(DiscourseTagging.visible_tags(guardian2)).to include(tag1)
      end

      it "includes tags with tags visible to everyone" do
        expect(DiscourseTagging.visible_tags(guardian2)).to include(tag2)
      end

      it "does not include tags which are only visible to staff" do
        expect(DiscourseTagging.visible_tags(guardian2)).not_to include(tag3)
      end

      it "does not include tags which are visible to members of another group" do
        expect(DiscourseTagging.visible_tags(guardian2)).not_to include(tag4)
      end
    end
  end

  describe "#validate_one_tag_from_group_per_topic" do
    fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag2, tag3], one_per_topic: true) }
    fab!(:topic) { Fabricate(:topic) }
    fab!(:category) { Fabricate(:category, allowed_tag_groups: [tag_group.name]) }

    it "returns true if the topic doesn't belong to a category" do
      result = DiscourseTagging.validate_one_tag_from_group_per_topic(nil, topic, nil, [tag1, tag2])
      expect(result).to eq(true)
    end

    it "returns true if only one tag is provided" do
      result = DiscourseTagging.validate_one_tag_from_group_per_topic(nil, topic, category, [tag1])
      expect(result).to eq(true)

      result = DiscourseTagging.validate_one_tag_from_group_per_topic(nil, topic, category, [tag2])
      expect(result).to eq(true)
    end

    it "returns true if only one tag in the group matches" do
      tag4 = Fabricate(:tag, name: "fun4")

      result =
        DiscourseTagging.validate_one_tag_from_group_per_topic(nil, topic, category, [tag1, tag4])
      expect(result).to eq(true)
    end

    context "when it fails" do
      it "returns false if more than one tag from the group is provided" do
        result =
          DiscourseTagging.validate_one_tag_from_group_per_topic(nil, topic, category, [tag1, tag2])

        expect(topic.errors[:base]&.first).to eq(
          I18n.t(
            "tags.limited_to_one_tag_from_group",
            tags: [tag1.name, tag2.name].sort.join(", "),
          ),
        )
        expect(result).to eq(false)
      end

      it "returns multiple errors when incompatible sets from more then one group are detected" do
        tag4 = Fabricate(:tag, name: "fun4")
        tag5 = Fabricate(:tag, name: "fun5")
        tag_group2 = Fabricate(:tag_group, tags: [tag4, tag5], one_per_topic: true)
        category2 = Fabricate(:category, allowed_tag_groups: [tag_group.name, tag_group2.name])

        result =
          DiscourseTagging.validate_one_tag_from_group_per_topic(
            nil,
            topic,
            category2,
            [tag1, tag2, tag4, tag5],
          )

        expect(topic.errors[:base]).to contain_exactly(
          *[[tag1.name, tag2.name], [tag4.name, tag5.name]].map do |failed_set|
            I18n.t("tags.limited_to_one_tag_from_group", tags: failed_set.sort.join(", "))
          end,
        )
        expect(result).to eq(false)
      end
    end
  end

  describe "#filter_tags_violating_one_tag_from_group_per_topic" do
    fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag2, tag3], one_per_topic: true) }

    context "when the topic doesn't belong to a category" do
      it "does not return tags that are not violating the one tag from group per topic rule" do
        tag4 = Fabricate(:tag, name: "fun4")
        tag5 = Fabricate(:tag, name: "fun5")

        invalid_tags =
          DiscourseTagging.filter_tags_violating_one_tag_from_group_per_topic(nil, [tag4, tag5])
        expect(invalid_tags).to be_empty
      end

      it "returns tags that are violating the one tag from group per topic rule when there is only one group" do
        invalid_tags =
          DiscourseTagging
            .filter_tags_violating_one_tag_from_group_per_topic(nil, [tag1, tag2])
            .values
            .first
            .map(&:name)
        expect(invalid_tags).to contain_exactly(tag1.name, tag2.name)
      end
    end

    context "when the topic belongs to a category" do
      context "when the category only allows tags from some tag groups" do
        it "returns tags that are violating the one tag from group per topic rule when there is only one group" do
          category = Fabricate(:category, allowed_tag_groups: [tag_group.name])

          [[tag1, tag2], [tag1, tag3], [tag2, tag3], [tag1, tag2, tag3]].each do |test_values|
            invalid_tags =
              DiscourseTagging
                .filter_tags_violating_one_tag_from_group_per_topic(category, test_values)
                .values
                .first
                .map(&:name)
            expect(invalid_tags).to contain_exactly(*test_values.map(&:name))
          end
        end

        it "returns tags that are violating the one tag from group per topic rule when there are multiple groups" do
          tag4 = Fabricate(:tag, name: "fun4")
          tag5 = Fabricate(:tag, name: "fun5")

          tag_group2 = Fabricate(:tag_group, tags: [tag4, tag5], one_per_topic: true)

          category = Fabricate(:category, allowed_tag_groups: [tag_group.name, tag_group2.name])

          [
            [tag1, tag2],
            [tag1, tag3],
            [tag2, tag3],
            [tag1, tag2, tag3],
            [tag4, tag5],
          ].each do |test_values|
            invalid_tags =
              DiscourseTagging
                .filter_tags_violating_one_tag_from_group_per_topic(category, test_values)
                .values
                .first
                .map(&:name)
            expect(invalid_tags).to contain_exactly(*test_values.map(&:name))
          end

          invalid_tags =
            DiscourseTagging
              .filter_tags_violating_one_tag_from_group_per_topic(
                category,
                [tag1, tag2, tag4, tag5],
              )
              .values
              .map { |tags| tags.map(&:name) }
          expect(invalid_tags).to contain_exactly([tag1.name, tag2.name], [tag4.name, tag5.name])
        end

        it "returns an empty array when only one tag is provided" do
          tag4 = Fabricate(:tag, name: "fun4")
          tag5 = Fabricate(:tag, name: "fun5")

          tag_group2 = Fabricate(:tag_group, tags: [tag4, tag5], one_per_topic: true)

          category = Fabricate(:category, allowed_tag_groups: [tag_group.name, tag_group2.name])

          [tag1, tag2, tag3, tag4, tag5].each do |tag|
            invalid_tags =
              DiscourseTagging.filter_tags_violating_one_tag_from_group_per_topic(category, [tag])
            expect(invalid_tags).to be_empty
          end
        end

        it "returns and empty array if the tags don't belong to a tag group" do
          tag4 = Fabricate(:tag, name: "fun4")
          tag5 = Fabricate(:tag, name: "fun5")

          category = Fabricate(:category, allowed_tag_groups: [tag_group.name])

          invalid_tags =
            DiscourseTagging.filter_tags_violating_one_tag_from_group_per_topic(
              category,
              [tag4, tag5],
            )
          expect(invalid_tags).to be_empty
        end
      end

      context "when some tag groups are required in the category" do
        it "returns tags that are violating the one tag from group per topic rule when there is only one group" do
          category =
            Fabricate(
              :category,
              category_required_tag_groups: [
                CategoryRequiredTagGroup.new(tag_group: tag_group, min_count: 1),
              ],
            )

          [[tag1, tag2], [tag1, tag3], [tag2, tag3], [tag1, tag2, tag3]].each do |test_values|
            invalid_tags =
              DiscourseTagging
                .filter_tags_violating_one_tag_from_group_per_topic(category, test_values)
                .values
                .first
                .map(&:name)
            expect(invalid_tags).to contain_exactly(*test_values.map(&:name))
          end
        end

        it "returns tags that are violating the one tag from group per topic rule when there are multiple groups" do
          tag4 = Fabricate(:tag, name: "fun4")
          tag5 = Fabricate(:tag, name: "fun5")

          tag_group2 = Fabricate(:tag_group, tags: [tag4, tag5], one_per_topic: true)

          category =
            Fabricate(
              :category,
              category_required_tag_groups: [
                CategoryRequiredTagGroup.new(tag_group: tag_group, min_count: 1),
                CategoryRequiredTagGroup.new(tag_group: tag_group2, min_count: 1),
              ],
            )

          [
            [tag1, tag2],
            [tag1, tag3],
            [tag2, tag3],
            [tag1, tag2, tag3],
            [tag4, tag5],
          ].each do |test_values|
            invalid_tags =
              DiscourseTagging
                .filter_tags_violating_one_tag_from_group_per_topic(category, test_values)
                .values
                .first
                .map(&:name)
            expect(invalid_tags).to contain_exactly(*test_values.map(&:name))
          end

          invalid_tags =
            DiscourseTagging
              .filter_tags_violating_one_tag_from_group_per_topic(
                category,
                [tag1, tag2, tag4, tag5],
              )
              .values
              .map { |tags| tags.map(&:name) }
          expect(invalid_tags).to contain_exactly([tag1.name, tag2.name], [tag4.name, tag5.name])
        end

        it "returns an empty array when only one tag is provided" do
          tag4 = Fabricate(:tag, name: "fun4")
          tag5 = Fabricate(:tag, name: "fun5")

          tag_group2 = Fabricate(:tag_group, tags: [tag4, tag5], one_per_topic: true)

          category =
            Fabricate(
              :category,
              category_required_tag_groups: [
                CategoryRequiredTagGroup.new(tag_group: tag_group, min_count: 1),
                CategoryRequiredTagGroup.new(tag_group: tag_group2, min_count: 1),
              ],
            )

          [tag1, tag2, tag3, tag4, tag5].each do |tag|
            invalid_tags =
              DiscourseTagging.filter_tags_violating_one_tag_from_group_per_topic(category, [tag])
            expect(invalid_tags).to be_empty
          end
        end

        it "returns and empty array if the tags don't belong to a tag group" do
          tag4 = Fabricate(:tag, name: "fun4")
          tag5 = Fabricate(:tag, name: "fun5")

          category =
            Fabricate(
              :category,
              category_required_tag_groups: [
                CategoryRequiredTagGroup.new(tag_group: tag_group, min_count: 1),
              ],
            )

          invalid_tags =
            DiscourseTagging.filter_tags_violating_one_tag_from_group_per_topic(
              category,
              [tag4, tag5],
            )
          expect(invalid_tags).to be_empty
        end
      end
    end
  end

  describe "filter_allowed_tags" do
    context "for input fields" do
      it "doesn't return selected tags if there's a search term" do
        tags =
          DiscourseTagging.filter_allowed_tags(
            Guardian.new(user),
            selected_tags: [tag2.name],
            for_input: true,
            term: "fun",
          ).map(&:name)
        expect(tags).to contain_exactly(tag1.name, tag3.name)
      end

      it "doesn't return selected tags if there's no search term" do
        tags =
          DiscourseTagging.filter_allowed_tags(
            Guardian.new(user),
            selected_tags: [tag2.name],
            for_input: true,
          ).map(&:name)
        expect(tags).to contain_exactly(tag1.name, tag3.name)
      end

      context "with tag with colon" do
        fab!(:tag_with_colon) { Fabricate(:tag, name: "with:colon") }

        it "can use it as selected tag" do
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              selected_tags: [tag_with_colon.name],
              for_input: true,
            ).map(&:name)
          expect(tags).to contain_exactly(tag1.name, tag2.name, tag3.name)
        end

        it "can search for tags with colons" do
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              term: "with:c",
              order_search_results: true,
            ).map(&:name)
          expect(tags).to contain_exactly(tag_with_colon.name)
        end

        it "can limit results to the tag" do
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_topic: true,
              only_tag_names: [tag_with_colon.name],
            ).map(&:name)
          expect(tags).to contain_exactly(tag_with_colon.name)
        end
      end

      context "with tags visible only to staff" do
        fab!(:hidden_tag) { Fabricate(:tag) }
        let!(:staff_tag_group) do
          Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
        end

        it "should return all tags to staff" do
          tags = DiscourseTagging.filter_allowed_tags(Guardian.new(admin)).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag1, tag2, tag3, hidden_tag]))
        end

        it "should not return hidden tag to non-staff" do
          tags = DiscourseTagging.filter_allowed_tags(Guardian.new(user)).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag1, tag2, tag3]))
        end
      end

      context "with tags visible only to non-admin group" do
        fab!(:hidden_tag) { Fabricate(:tag) }
        fab!(:group) { Fabricate(:group, name: "my-group") }
        let!(:user_tag_group) do
          Fabricate(:tag_group, permissions: { "my-group" => 1 }, tag_names: [hidden_tag.name])
        end

        before { group.add(user) }

        it "should return all tags to member of group" do
          tags = DiscourseTagging.filter_allowed_tags(Guardian.new(user)).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag1, tag2, tag3, hidden_tag]))
        end

        it "should allow a tag group to have multiple group permissions" do
          group2 = Fabricate(:group, name: "another-group")
          user2 = Fabricate(:user)
          user3 = Fabricate(:user)
          group2.add(user2)
          user_tag_group.update!(permissions: { "my-group" => 1, "another-group" => 1 })

          tags = DiscourseTagging.filter_allowed_tags(Guardian.new(user)).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag1, tag2, tag3, hidden_tag]))

          tags = DiscourseTagging.filter_allowed_tags(Guardian.new(user2)).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag1, tag2, tag3, hidden_tag]))

          tags = DiscourseTagging.filter_allowed_tags(Guardian.new(user3)).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag1, tag2, tag3]))
        end

        it "should not hide group tags to member of group" do
          tags = DiscourseTagging.hidden_tag_names(Guardian.new(user)).to_a
          expect(sorted_tag_names(tags)).to eq([])
        end

        it "should hide group tags to non-member of group" do
          other_user = Fabricate(:user)
          tags = DiscourseTagging.hidden_tag_names(Guardian.new(other_user)).to_a
          expect(sorted_tag_names(tags)).to eq([hidden_tag.name])
        end
      end

      context "with required tags from tag group" do
        fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag2]) }
        fab!(:category) do
          Fabricate(
            :category,
            category_required_tag_groups: [
              CategoryRequiredTagGroup.new(tag_group: tag_group, min_count: 1),
            ],
          )
        end

        it "returns the required tags if none have been selected" do
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
              term: "fun",
            ).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag1, tag2]))
        end

        it "returns all allowed tags if a required tag is selected" do
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
              selected_tags: [tag1.name],
              term: "fun",
            ).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag2, tag3]))
        end

        it "returns required tags if not enough are selected" do
          category.category_required_tag_groups.first.update!(min_count: 2)
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
              selected_tags: [tag1.name],
              term: "fun",
            ).to_a
          expect(sorted_tag_names(tags)).to contain_exactly(tag2.name)
        end

        it "lets staff ignore the requirement" do
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(admin),
              for_input: true,
              category: category,
              limit: 5,
            ).to_a

          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag1, tag2, tag3]))
        end

        it "handles multiple required tag groups in sequence" do
          tag4 = Fabricate(:tag)
          tag_group_2 = Fabricate(:tag_group, tags: [tag4])
          CategoryRequiredTagGroup.create!(
            category: category,
            tag_group: tag_group_2,
            min_count: 1,
            order: 2,
          )

          category.reload

          # In the beginning, show tags for tag_group
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
            ).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag1, tag2]))

          # Once a tag_group tag has been selected, move on to tag_group_2 tags
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
              selected_tags: [tag1.name],
            ).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag4]))

          # Once all requirements are satisfied, show all tags
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
              selected_tags: [tag1.name, tag4.name],
            ).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag2, tag3]))
        end
      end

      context "with tag groups restricted to the category in which the number of tags per topic is limited to one" do
        fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag2, tag3], one_per_topic: true) }
        fab!(:tag_group2) { Fabricate(:tag_group, tags: [tag1, tag2], one_per_topic: true) }

        it "doesn't return tags leaked from other tag groups containing the same tags" do
          # this tests covers the bug described in
          # https://meta.discourse.org/t/limiting-tags-to-categories-not-working-as-expected/263143

          category = Fabricate(:category, tag_groups: [tag_group])

          # In the beginning, show tags for tag_group
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
            ).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag1, tag2, tag3]))

          # Once a tag has been selected it should not return any tags from the same group
          # this is where the problem reported in the bug linked above was happening
          # If the user selected a tag that belonged only to the tag group restricted to the category but other tags
          # from the same tag group were also present in other tag groups, they were being returned because they were
          # bleeding from the tag list as the filter performed in the query was scoping only the category to apply the
          # restriction. Since the join was done on tag_id, it was returning all tags with the same ids even if they
          # actually belonged to other tag groups that should not be returned because the category was not restricted
          # to them
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
              selected_tags: [tag3.name],
            ).to_a
          expect(sorted_tag_names(tags)).to be_empty
        end

        it "doesn't return a tag excluded from a tag group even if also belongs to another allowed one" do
          tag4 = Fabricate(:tag)
          tag5 = Fabricate(:tag)
          tag_group3 = Fabricate(:tag_group, tags: [tag3, tag4], one_per_topic: true)

          category = Fabricate(:category, tag_groups: [tag_group, tag_group2, tag_group3])

          # In the beginning, show all expected tags
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
            ).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag1, tag2, tag3, tag4]))

          # tag3 belongs to tag_group1 and tag_group3. no tags from both groups should be returned
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
              selected_tags: [tag3.name],
            ).to_a
          expect(sorted_tag_names(tags)).to be_empty

          # tag4 only belong belongs to tag_group3. tag1 and tag2 should be returned because they belong to tag_group1
          # and tag_group2 but don't belong to tag_group3
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
              selected_tags: [tag4.name],
            ).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag1, tag2]))
        end

        it "returns correctly tags from other restricted tag groups when they're not limited to one" do
          tag4 = Fabricate(:tag, name: "fun4")
          tag5 = Fabricate(:tag, name: "fun5")
          tag_group3 = Fabricate(:tag_group, tags: [tag4, tag5])

          category = Fabricate(:category, tag_groups: [tag_group, tag_group2, tag_group3])

          # In the beginning, show all expected tags
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
            ).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag1, tag2, tag3, tag4, tag5]))

          # Once a tag from a limited group has been selected it should not return any tags from the same group
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
              selected_tags: [tag1.name],
            ).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag4, tag5]))

          # if a tag from the group not limited to one tag is also selected the other should be returned
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
              selected_tags: [tag1.name, tag4.name],
            ).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag5]))

          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
              selected_tags: [tag1.name, tag5.name],
            ).to_a
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag4]))

          # finally if all the tags from the group not limited to one tag are also selected, then there is no other
          # tag to return
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              category: category,
              selected_tags: [tag1.name, tag4.name, tag5.name],
            ).to_a
          expect(sorted_tag_names(tags)).to be_empty
        end
      end

      context "with many required tags in a tag group" do
        fab!(:tag4) { Fabricate(:tag, name: "T4") }
        fab!(:tag5) { Fabricate(:tag, name: "T5") }
        fab!(:tag6) { Fabricate(:tag, name: "T6") }
        fab!(:tag7) { Fabricate(:tag, name: "T7") }
        fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag2, tag4, tag5, tag6, tag7]) }
        fab!(:category) do
          Fabricate(
            :category,
            category_required_tag_groups: [
              CategoryRequiredTagGroup.new(tag_group: tag_group, min_count: 1),
            ],
          )
        end

        it "returns required tags for staff by default" do
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(admin),
              for_input: true,
              category: category,
            ).to_a
          expect(sorted_tag_names(tags)).to eq(
            sorted_tag_names([tag1, tag2, tag4, tag5, tag6, tag7]),
          )
        end

        it "ignores required tags for staff when searching using a term" do
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(admin),
              for_input: true,
              category: category,
              term: "fun",
            ).to_a

          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag1, tag2, tag3]))
        end

        it "returns required tags for nonstaff and overrides limit" do
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              limit: 5,
              category: category,
            ).to_a
          expect(sorted_tag_names(tags)).to eq(
            sorted_tag_names([tag1, tag2, tag4, tag5, tag6, tag7]),
          )
        end
      end

      context "with empty term" do
        it "works with an empty term" do
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              term: "",
              order_search_results: true,
            ).map(&:name)
          expect(sorted_tag_names(tags)).to eq(sorted_tag_names([tag1, tag2, tag3]))
        end
      end

      context "with tag synonyms" do
        fab!(:base_tag) { Fabricate(:tag, name: "discourse") }
        fab!(:synonym) { Fabricate(:tag, name: "discource", target_tag: base_tag) }

        it "returns synonyms by default" do
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              term: "disc",
            ).map(&:name)
          expect(tags).to contain_exactly(base_tag.name, synonym.name)
        end

        it "excludes synonyms with exclude_synonyms param" do
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              exclude_synonyms: true,
              term: "disc",
            ).map(&:name)
          expect(tags).to contain_exactly(base_tag.name)
        end

        it "excludes tags with synonyms with exclude_has_synonyms params" do
          tags =
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              exclude_has_synonyms: true,
              term: "disc",
            ).map(&:name)
          expect(tags).to contain_exactly(synonym.name)
        end

        it "can exclude synonyms and tags with synonyms" do
          expect(
            DiscourseTagging.filter_allowed_tags(
              Guardian.new(user),
              for_input: true,
              exclude_has_synonyms: true,
              exclude_synonyms: true,
              term: "disc",
            ),
          ).to be_empty
        end
      end
    end
  end

  describe "filter_visible" do
    fab!(:hidden_tag) { Fabricate(:tag) }
    let!(:staff_tag_group) do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
    end
    fab!(:topic) { Fabricate(:topic, tags: [tag1, tag2, tag3, hidden_tag]) }

    it "returns all tags to staff" do
      tags = DiscourseTagging.filter_visible(topic.tags, Guardian.new(admin))
      expect(tags.size).to eq(4)
      expect(tags).to contain_exactly(tag1, tag2, tag3, hidden_tag)
    end

    it "does not return hidden tags to non-staff" do
      tags = DiscourseTagging.filter_visible(topic.tags, Guardian.new(user))
      expect(tags.size).to eq(3)
      expect(tags).to contain_exactly(tag1, tag2, tag3)
    end

    it "returns staff only tags to everyone" do
      create_staff_only_tags(["important"])
      staff_tag = Tag.where(name: "important").first
      topic.tags << staff_tag
      tags = DiscourseTagging.filter_visible(topic.tags, Guardian.new(user))
      expect(tags.size).to eq(4)
      expect(tags).to contain_exactly(tag1, tag2, tag3, staff_tag)
    end
  end

  describe "tag_topic_by_names" do
    context "with visible but restricted tags" do
      fab!(:topic) { Fabricate(:topic) }

      before { create_staff_only_tags(["alpha"]) }

      it "regular users can't add staff-only tags" do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), ["alpha"])
        expect(valid).to eq(false)
        expect(topic.errors[:base]&.first).to eq(
          I18n.t("tags.restricted_tag_disallowed", tag: "alpha"),
        )
      end

      it "does not send a discourse event for regular users who can't add staff-only tags" do
        events =
          DiscourseEvent.track_events do
            DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), ["alpha"])
          end
        expect(events.count).to eq(0)
      end

      it "staff can add staff-only tags" do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(admin), ["alpha"])
        expect(valid).to eq(true)
        expect(topic.errors[:base]).to be_empty
      end

      it "sends a discourse event when the staff adds a staff-only tag" do
        old_tag_names = topic.tags.pluck(:name)
        tag_changed_event =
          DiscourseEvent
            .track_events do
              DiscourseTagging.tag_topic_by_names(topic, Guardian.new(admin), ["alpha"])
            end
            .last
        expect(tag_changed_event[:event_name]).to eq(:topic_tags_changed)
        expect(tag_changed_event[:params].first).to eq(topic)
        expect(tag_changed_event[:params].second[:old_tag_names]).to eq(old_tag_names)
        expect(tag_changed_event[:params].second[:new_tag_names]).to eq(["alpha"])
      end

      context "with non-staff users in tag group groups" do
        fab!(:non_staff_group) { Fabricate(:group, name: "non_staff_group") }

        before { create_limited_tags("Group for Non-Staff", non_staff_group.id, ["alpha"]) }

        it "can use hidden tag if in correct group" do
          non_staff_group.add(user)

          valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), ["alpha"])

          expect(valid).to eq(true)
          expect(topic.errors[:base]).to be_empty
        end

        it "will return error if user is not in correct group" do
          user2 = Fabricate(:user)
          valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user2), ["alpha"])
          expect(valid).to eq(false)
        end
      end
    end

    it "respects category allow_global_tags setting" do
      tag = Fabricate(:tag)
      other_tag = Fabricate(:tag)
      tag_group = Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag.name])
      category = Fabricate(:category, allowed_tag_groups: [tag_group.name])
      other_category = Fabricate(:category, allowed_tags: [other_tag.name])
      topic = Fabricate(:topic, category: category)

      result =
        DiscourseTagging.tag_topic_by_names(
          topic,
          Guardian.new(admin),
          [tag.name, other_tag.name, "hello"],
        )
      expect(result).to eq(true)
      expect(topic.tags.pluck(:name)).to contain_exactly(tag.name)

      category.update!(allow_global_tags: true)
      result =
        DiscourseTagging.tag_topic_by_names(
          topic,
          Guardian.new(admin),
          [tag.name, other_tag.name, "hello"],
        )
      expect(result).to eq(true)
      expect(topic.tags.pluck(:name)).to contain_exactly(tag.name, "hello")
    end

    it "raises an error if no tags could be updated" do
      tag = Fabricate(:tag)
      other_tag = Fabricate(:tag)
      tag_group = Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag.name])
      category = Fabricate(:category, allowed_tag_groups: [tag_group.name])
      other_category = Fabricate(:category, allowed_tags: [other_tag.name])
      topic = Fabricate(:topic, category: category)

      result = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(admin), [other_tag.name])
      expect(result).to eq(false)
      expect(topic.tags.pluck(:name)).to be_blank
    end

    it "can remove tags and keep existent ones" do
      tag1 = Fabricate(:tag)
      tag2 = Fabricate(:tag)
      topic = Fabricate(:topic, tags: [tag1, tag2])
      Fabricate(:category, allowed_tags: [tag1.name])

      result = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(admin), [tag1.name])

      expect(result).to eq(true)
      expect(topic.reload.tags.pluck(:name)).to eq([tag1.name])
    end

    context "when respecting category minimum_required_tags setting" do
      fab!(:category) { Fabricate(:category, minimum_required_tags: 2) }
      fab!(:topic) { Fabricate(:topic, category: category) }

      it "when tags are not present" do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [])
        expect(valid).to eq(false)
        expect(topic.errors[:base]&.first).to eq(
          I18n.t("tags.minimum_required_tags", count: category.minimum_required_tags),
        )
      end

      it "when tags are less than minimum_required_tags" do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [tag1.name])
        expect(valid).to eq(false)
        expect(topic.errors[:base]&.first).to eq(
          I18n.t("tags.minimum_required_tags", count: category.minimum_required_tags),
        )
      end

      it "when tags are equal to minimum_required_tags" do
        valid =
          DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [tag1.name, tag2.name])
        expect(valid).to eq(true)
        expect(topic.errors[:base]).to be_empty
      end

      it "lets admin tag a topic regardless of minimum_required_tags" do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(admin), [tag1.name])
        expect(valid).to eq(true)
        expect(topic.errors[:base]).to be_empty
      end
    end

    context "with hidden tags" do
      fab!(:hidden_tag) { Fabricate(:tag) }
      let!(:staff_tag_group) do
        Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
      end
      fab!(:topic) { Fabricate(:topic, user: user) }
      fab!(:post) { Fabricate(:post, user: user, topic: topic, post_number: 1) }

      it "user cannot add hidden tag by knowing its name" do
        expect(
          PostRevisor.new(post).revise!(
            topic.user,
            raw: post.raw + " edit",
            tags: [hidden_tag.name],
          ),
        ).to be_falsey
        expect(topic.reload.tags).to be_empty
      end

      it "admin can add hidden tag" do
        expect(
          PostRevisor.new(post).revise!(admin, raw: post.raw, tags: [hidden_tag.name]),
        ).to be_truthy
        expect(topic.reload.tags).to eq([hidden_tag])
      end

      it "user does not get an error when editing their topic with a hidden tag" do
        PostRevisor.new(post).revise!(admin, raw: post.raw, tags: [hidden_tag.name])

        expect(
          PostRevisor.new(post).revise!(topic.user, raw: post.raw + " edit", tags: []),
        ).to be_truthy

        expect(topic.reload.tags).to eq([hidden_tag])
      end
    end

    context "with tag group with parent tag" do
      let(:topic) { Fabricate(:topic, user: user) }
      let(:post) { Fabricate(:post, user: user, topic: topic, post_number: 1) }
      let(:tag_group) { Fabricate(:tag_group, parent_tag_id: tag1.id) }

      before { tag_group.tags = [tag3] }

      it "can tag with parent" do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [tag1.name])
        expect(valid).to eq(true)
        expect(topic.reload.tags.map(&:name)).to eq([tag1.name])
      end

      it "can tag with parent and a tag" do
        valid =
          DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [tag1.name, tag3.name])
        expect(valid).to eq(true)
        expect(topic.reload.tags.map(&:name)).to contain_exactly(*[tag1, tag3].map(&:name))
      end

      it "adds all parent tags that are missing" do
        parent_tag = Fabricate(:tag, name: "parent")
        tag_group2 = Fabricate(:tag_group, parent_tag_id: parent_tag.id)
        tag_group2.tags = [tag2]
        valid =
          DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [tag3.name, tag2.name])
        expect(valid).to eq(true)
        expect(topic.reload.tags.map(&:name)).to contain_exactly(
          *[tag1, tag2, tag3, parent_tag].map(&:name),
        )
      end

      it "fails when parent tag missing will conflict with another tag from tag group set to one tag per topic" do
        parent_tag = Fabricate(:tag, name: "parent-1")
        parent_tag2 = Fabricate(:tag, name: "parent-2")
        parent_tag_group =
          Fabricate(:tag_group, tags: [parent_tag, parent_tag2], one_per_topic: true)

        tag4 = Fabricate(:tag, name: "fun4")
        tag5 = Fabricate(:tag, name: "fun5")

        child_tag_group =
          Fabricate(:tag_group, tags: [tag1, tag2, tag3], parent_tag_id: parent_tag.id)
        child_tag_group2 = Fabricate(:tag_group, tags: [tag4, tag5], parent_tag_id: parent_tag2.id)

        tag_limited_category =
          Fabricate(
            :category,
            allowed_tag_groups: [
              parent_tag_group.name,
              child_tag_group.name,
              child_tag_group2.name,
            ],
          )

        topic = Fabricate(:topic, category: tag_limited_category)

        # tag2 will insert parent_tag which is missing. parent_tag will conflict with parent_tag2
        valid =
          DiscourseTagging.tag_topic_by_names(
            topic,
            Guardian.new(user),
            [parent_tag2.name, tag2.name],
          )
        expect(valid).to eq(false)
        expect(topic.errors[:base]&.first).to eq(
          I18n.t(
            "tags.limited_to_one_tag_from_group",
            tags: [parent_tag2.name, tag2.name].sort.join(", "),
          ),
        )

        topic = Fabricate(:topic, category: tag_limited_category)

        # tag4 will insert parent_tag2 which is missing. parent_tag will conflict with parent_tag2
        valid =
          DiscourseTagging.tag_topic_by_names(
            topic,
            Guardian.new(user),
            [parent_tag.name, tag1.name, tag4.name],
          )
        expect(valid).to eq(false)
        expect(topic.errors[:base]&.first).to eq(
          I18n.t(
            "tags.limited_to_one_tag_from_group",
            tags: [parent_tag.name, tag4.name].sort.join(", "),
          ),
        )
      end

      it "fails when multiple parent tag missing will conflict with another tag from tag group set to one tag per topic" do
        parent_tag = Fabricate(:tag, name: "parent-1")
        parent_tag2 = Fabricate(:tag, name: "parent-2")
        parent_tag3 = Fabricate(:tag, name: "parent-3")
        parent_tag_group =
          Fabricate(:tag_group, tags: [parent_tag, parent_tag2, parent_tag3], one_per_topic: true)

        tag4 = Fabricate(:tag, name: "fun4")
        tag5 = Fabricate(:tag, name: "fun5")

        child_tag_group =
          Fabricate(:tag_group, tags: [tag1, tag2, tag3], parent_tag_id: parent_tag.id)
        child_tag_group2 = Fabricate(:tag_group, tags: [tag4], parent_tag_id: parent_tag2.id)
        child_tag_group3 = Fabricate(:tag_group, tags: [tag5], parent_tag_id: parent_tag3.id)

        tag_limited_category =
          Fabricate(
            :category,
            allowed_tag_groups: [
              parent_tag_group.name,
              child_tag_group.name,
              child_tag_group2.name,
              child_tag_group3.name,
            ],
          )

        topic = Fabricate(:topic, category: tag_limited_category)

        # tag4 and tag5 will insert parent_tag2 and parent_tag3 which are missing. they will conflict with parent_tag
        valid =
          DiscourseTagging.tag_topic_by_names(
            topic,
            Guardian.new(user),
            [parent_tag.name, tag4.name, tag5.name],
          )
        expect(valid).to eq(false)
        expect(topic.errors[:base]&.first).to eq(
          I18n.t(
            "tags.limited_to_one_tag_from_group",
            tags: [parent_tag.name, tag4.name, tag5.name].sort.join(", "),
          ),
        )
      end

      it "fails when multiple parent tag missing will conflict in tag group set to one tag per topic" do
        parent_tag = Fabricate(:tag, name: "parent-1")
        parent_tag2 = Fabricate(:tag, name: "parent-2")
        parent_tag_group =
          Fabricate(:tag_group, tags: [parent_tag, parent_tag2], one_per_topic: true)

        tag4 = Fabricate(:tag, name: "fun4")
        tag5 = Fabricate(:tag, name: "fun5")

        child_tag_group =
          Fabricate(:tag_group, tags: [tag1, tag2, tag3], parent_tag_id: parent_tag.id)
        child_tag_group2 = Fabricate(:tag_group, tags: [tag4, tag5], parent_tag_id: parent_tag2.id)

        tag_limited_category =
          Fabricate(
            :category,
            allowed_tag_groups: [
              parent_tag_group.name,
              child_tag_group.name,
              child_tag_group2.name,
            ],
          )

        topic = Fabricate(:topic, category: tag_limited_category)

        # tag1 and tag4 will insert parent_tag and parent_tag2 which are missing. they will conflict with each other
        valid =
          DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [tag1.name, tag4.name])
        expect(valid).to eq(false)
        expect(topic.errors[:base]&.first).to eq(
          I18n.t(
            "tags.limited_to_one_tag_from_group",
            tags: [tag1.name, tag4.name].sort.join(", "),
          ),
        )
      end

      it "fails with multiple errors when parent tag missing will conflict in more than one tag group set to one tag per topic" do
        parent_tag = Fabricate(:tag, name: "parent-1")
        parent_tag2 = Fabricate(:tag, name: "parent-2")
        parent_tag_group =
          Fabricate(:tag_group, tags: [parent_tag, parent_tag2], one_per_topic: true)

        parent_tag3 = Fabricate(:tag, name: "parent-3")
        parent_tag4 = Fabricate(:tag, name: "parent-4")
        parent_tag_group2 =
          Fabricate(:tag_group, tags: [parent_tag3, parent_tag4], one_per_topic: true)

        tag4 = Fabricate(:tag, name: "fun4")

        child_tag_group = Fabricate(:tag_group, tags: [tag1], parent_tag_id: parent_tag.id)
        child_tag_group2 = Fabricate(:tag_group, tags: [tag2], parent_tag_id: parent_tag2.id)
        child_tag_group3 = Fabricate(:tag_group, tags: [tag3], parent_tag_id: parent_tag3.id)
        child_tag_group4 = Fabricate(:tag_group, tags: [tag4], parent_tag_id: parent_tag4.id)

        tag_limited_category =
          Fabricate(
            :category,
            allowed_tag_groups: [
              parent_tag_group.name,
              parent_tag_group2.name,
              child_tag_group.name,
              child_tag_group2.name,
              child_tag_group3.name,
              child_tag_group4.name,
            ],
          )

        topic = Fabricate(:topic, category: tag_limited_category)

        # tag2 will insert parent_tag2 which is missing. it will conflict with parent_tag
        # tag4 will insert parent_tag4 which is missing. it will conflict with parent_tag3
        valid =
          DiscourseTagging.tag_topic_by_names(
            topic,
            Guardian.new(user),
            [parent_tag.name, tag2.name, parent_tag3.name, tag4.name],
          )
        expect(valid).to eq(false)
        expect(topic.errors[:base]).to contain_exactly(
          *[[parent_tag.name, tag2.name], [parent_tag3.name, tag4.name]].map do |conflicting_tags|
            I18n.t("tags.limited_to_one_tag_from_group", tags: conflicting_tags.sort.join(", "))
          end,
        )
      end

      it "adds only the necessary parent tags" do
        common = Fabricate(:tag, name: "common")
        tag_group.tags = [tag3, common]

        parent_tag = Fabricate(:tag, name: "parent")
        tag_group2 = Fabricate(:tag_group, parent_tag_id: parent_tag.id)
        tag_group2.tags = [tag2, common]

        valid =
          DiscourseTagging.tag_topic_by_names(
            topic,
            Guardian.new(user),
            [parent_tag.name, common.name],
          )
        expect(valid).to eq(true)
        expect(topic.reload.tags.map(&:name)).to contain_exactly(*[parent_tag, common].map(&:name))
      end
    end

    context "when enforcing required tags from a tag group" do
      fab!(:category) { Fabricate(:category) }
      fab!(:tag_group) { Fabricate(:tag_group) }
      fab!(:topic) { Fabricate(:topic, category: category) }

      before do
        tag_group.tags = [tag1, tag2]
        category.update(
          category_required_tag_groups: [
            CategoryRequiredTagGroup.new(tag_group: tag_group, min_count: 1),
          ],
        )
      end

      it "when no tags are present" do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [])
        expect(valid).to eq(false)
        expect(topic.errors[:base]&.first).to eq(
          I18n.t(
            "tags.required_tags_from_group",
            count: 1,
            tag_group_name: tag_group.name,
            tags: tag_group.tags.pluck(:name).join(", "),
          ),
        )
      end

      it "when tags are not part of the tag group" do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [tag3.name])
        expect(valid).to eq(false)
        expect(topic.errors[:base]&.first).to eq(
          I18n.t(
            "tags.required_tags_from_group",
            count: 1,
            tag_group_name: tag_group.name,
            tags: tag_group.tags.pluck(:name).join(", "),
          ),
        )
      end

      it "when requirement is met" do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [tag1.name])
        expect(valid).to eq(true)
        valid =
          DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [tag1.name, tag2.name])
        expect(valid).to eq(true)
        valid =
          DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [tag2.name, tag3.name])
        expect(valid).to eq(true)
      end

      it "lets staff ignore the restriction" do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(admin), [])
        expect(valid).to eq(true)
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(admin), [tag3.name])
        expect(valid).to eq(true)
      end
    end

    context "with tag synonyms" do
      fab!(:topic) { Fabricate(:topic) }

      fab!(:syn1) { Fabricate(:tag, name: "synonym1", target_tag: tag1) }
      fab!(:syn2) { Fabricate(:tag, name: "synonym2", target_tag: tag1) }

      it "uses the base tag when a synonym is given" do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [syn1.name])
        expect(valid).to eq(true)
        expect(topic.errors[:base]).to be_empty
        expect_same_tag_names(topic.reload.tags, [tag1])
      end

      it "handles multiple synonyms for the same tag" do
        valid =
          DiscourseTagging.tag_topic_by_names(
            topic,
            Guardian.new(user),
            [tag1.name, syn1.name, syn2.name],
          )
        expect(valid).to eq(true)
        expect(topic.errors[:base]).to be_empty
        expect_same_tag_names(topic.reload.tags, [tag1])
      end
    end
  end

  describe "#tags_for_saving" do
    it "returns empty array if input is nil" do
      expect(described_class.tags_for_saving(nil, guardian)).to eq([])
    end

    it "returns empty array if input is empty" do
      expect(described_class.tags_for_saving([], guardian)).to eq([])
    end

    it "returns empty array if can't tag topics" do
      guardian.stubs(:can_tag_topics?).returns(false)
      expect(described_class.tags_for_saving(["newtag"], guardian)).to eq([])
    end

    describe "can tag topics but not create tags" do
      before do
        guardian.stubs(:can_create_tag?).returns(false)
        guardian.stubs(:can_tag_topics?).returns(true)
      end

      it "returns empty array if all tags are new" do
        expect(described_class.tags_for_saving(%w[newtag newtagplz], guardian)).to eq([])
      end

      it "returns only existing tag names" do
        Fabricate(:tag, name: "oldtag")
        Fabricate(:tag, name: "oldTag2")
        expect(
          described_class.tags_for_saving(%w[newtag oldtag oldtag2], guardian),
        ).to contain_exactly("oldtag", "oldTag2")
      end
    end

    describe "can tag topics and create tags" do
      before do
        guardian.stubs(:can_create_tag?).returns(true)
        guardian.stubs(:can_tag_topics?).returns(true)
      end

      it "returns given tag names if can create new tags and tag topics" do
        expect(described_class.tags_for_saving(%w[newtag1 newtag2], guardian).try(:sort)).to eq(
          %w[newtag1 newtag2],
        )
      end

      it "only sanitizes new tags" do
        # for backwards compat
        Tag.new(name: "math=fun").save(validate: false)
        expect(
          described_class.tags_for_saving(%w[math=fun fun*2@gmail.com], guardian).try(:sort),
        ).to eq(%w[math=fun fun2gmailcom].sort)
      end
    end

    describe "clean_tag" do
      it "downcases new tags if setting enabled" do
        expect(DiscourseTagging.clean_tag("HeLlO")).to eq("hello")

        SiteSetting.force_lowercase_tags = false
        expect(DiscourseTagging.clean_tag("HeLlO")).to eq("HeLlO")
      end

      it "removes zero-width spaces" do
        expect(DiscourseTagging.clean_tag("hel\ufefflo")).to eq("hello")
      end
    end
  end

  describe "staff_tag_names" do
    fab!(:tag) { Fabricate(:tag) }

    fab!(:staff_tag) { Fabricate(:tag) }
    fab!(:other_staff_tag) { Fabricate(:tag) }

    let!(:staff_tag_group) do
      Fabricate(
        :tag_group,
        permissions: {
          "staff" => 1,
          "everyone" => 3,
        },
        tag_names: [staff_tag.name],
      )
    end

    it "returns all staff tags" do
      expect(DiscourseTagging.staff_tag_names).to contain_exactly(staff_tag.name)

      staff_tag_group.update(tag_names: [staff_tag.name, other_staff_tag.name])
      expect(DiscourseTagging.staff_tag_names).to contain_exactly(
        staff_tag.name,
        other_staff_tag.name,
      )

      staff_tag_group.update(tag_names: [other_staff_tag.name])
      expect(DiscourseTagging.staff_tag_names).to contain_exactly(other_staff_tag.name)
    end
  end

  describe "#add_or_create_synonyms_by_name" do
    it "can add an existing tag" do
      expect {
        expect(DiscourseTagging.add_or_create_synonyms_by_name(tag1, [tag2.name])).to eq(true)
      }.to_not change { Tag.count }
      expect_same_tag_names(tag1.reload.synonyms, [tag2])
      expect(tag2.reload.target_tag).to eq(tag1)
    end

    it "can add an existing tag when both tags added to same topic" do
      topic = Fabricate(:topic, tags: [tag1, tag2, tag3])
      expect {
        expect(DiscourseTagging.add_or_create_synonyms_by_name(tag1, [tag2.name])).to eq(true)
      }.to_not change { Tag.count }
      expect_same_tag_names(tag1.reload.synonyms, [tag2])
      expect_same_tag_names(topic.reload.tags, [tag1, tag3])
      expect(tag2.reload.target_tag).to eq(tag1)
    end

    it "can add existing tag with wrong case" do
      expect {
        expect(DiscourseTagging.add_or_create_synonyms_by_name(tag1, [tag2.name.upcase])).to eq(
          true,
        )
      }.to_not change { Tag.count }
      expect_same_tag_names(tag1.reload.synonyms, [tag2])
      expect(tag2.reload.target_tag).to eq(tag1)
    end

    it "removes target tag name from synonyms if present " do
      expect {
        expect(DiscourseTagging.add_or_create_synonyms_by_name(tag1, [tag1.name, tag2.name])).to eq(
          true,
        )
      }.to_not change { Tag.count }
      expect_same_tag_names(tag1.reload.synonyms, [tag2])
      expect(tag2.reload.target_tag).to eq(tag1)
    end

    it "can create new tags" do
      expect {
        expect(DiscourseTagging.add_or_create_synonyms_by_name(tag1, ["synonym1"])).to eq(true)
      }.to change { Tag.count }.by(1)
      s = Tag.where_name("synonym1").first
      expect_same_tag_names(tag1.reload.synonyms, [s])
      expect(s.target_tag).to eq(tag1)
    end

    it "can add existing and new tags" do
      expect {
        expect(
          DiscourseTagging.add_or_create_synonyms_by_name(tag1, [tag2.name, "synonym1"]),
        ).to eq(true)
      }.to change { Tag.count }.by(1)
      s = Tag.where_name("synonym1").first
      expect_same_tag_names(tag1.reload.synonyms, [tag2, s])
      expect(s.target_tag).to eq(tag1)
      expect(tag2.reload.target_tag).to eq(tag1)
    end

    it "can change a synonym's target tag" do
      synonym = Fabricate(:tag, name: "synonym1", target_tag: tag1)
      expect {
        expect(DiscourseTagging.add_or_create_synonyms_by_name(tag2, [synonym.name])).to eq(true)
      }.to_not change { Tag.count }
      expect_same_tag_names(tag2.reload.synonyms, [synonym])
      expect(tag1.reload.synonyms.count).to eq(0)
      expect(synonym.reload.target_tag).to eq(tag2)
    end

    it "doesn't allow tags that have synonyms to become synonyms" do
      tag2.synonyms << Fabricate(:tag)
      value = DiscourseTagging.add_or_create_synonyms_by_name(tag1, [tag2.name])
      expect(value).to be_a(Array)
      expect(value.size).to eq(1)
      expect(value.first.errors[:target_tag_id]).to be_present
      expect(tag1.reload.synonyms.count).to eq(0)
      expect(tag2.reload.synonyms.count).to eq(1)
    end

    it "changes tag of topics" do
      topic = Fabricate(:topic, tags: [tag2])
      expect(DiscourseTagging.add_or_create_synonyms_by_name(tag1, [tag2.name])).to eq(true)
      expect_same_tag_names(topic.reload.tags, [tag1])

      tag1.reload

      expect(tag1.public_topic_count).to eq(1)
      expect(tag1.staff_topic_count).to eq(1)

      tag2.reload

      expect(tag2.public_topic_count).to eq(0)
      expect(tag2.staff_topic_count).to eq(0)
    end
  end
end
