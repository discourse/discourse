# frozen_string_literal: true

RSpec.describe TagResource do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  fab!(:plain) { Fabricate(:tag, name: "plain") }
  fab!(:parent) { Fabricate(:tag, name: "parent") }
  fab!(:child) { Fabricate(:tag, name: "child") }
  fab!(:readonly_tag) { Fabricate(:tag, name: "readonly-tag") }
  fab!(:shared) { Fabricate(:tag, name: "shared") }
  fab!(:split) { Fabricate(:tag, name: "split") }
  fab!(:linux) { Fabricate(:tag, name: "linux") }
  fab!(:mac) { Fabricate(:tag, name: "mac") }
  fab!(:cat_only) { Fabricate(:tag, name: "cat-only") }
  fab!(:cat_group_tag) { Fabricate(:tag, name: "cat-group-tag") }
  fab!(:global_cat_tag) { Fabricate(:tag, name: "global-cat-tag") }
  fab!(:req_one) { Fabricate(:tag, name: "req-one") }
  fab!(:req_two) { Fabricate(:tag, name: "req-two") }

  fab!(:child_group) { Fabricate(:tag_group, parent_tag_id: parent.id, tags: [child, split]) }
  fab!(:readonly_group) do
    Fabricate(
      :tag_group,
      tags: [readonly_tag, shared, split],
      permissions: {
        "everyone" => TagGroupPermission.permission_types[:readonly],
        "staff" => TagGroupPermission.permission_types[:full],
      },
    )
  end
  fab!(:public_group) { Fabricate(:tag_group, tags: [shared]) }
  fab!(:os_group) { Fabricate(:tag_group, one_per_topic: true, tags: [linux, mac]) }
  fab!(:cat_group) { Fabricate(:tag_group, tags: [cat_group_tag]) }
  fab!(:req_group) { Fabricate(:tag_group, tags: [req_one, req_two]) }

  fab!(:open_category, :category)
  fab!(:restricted) { Fabricate(:category, tags: [cat_only], tag_groups: [cat_group]) }
  fab!(:restricted_global) { Fabricate(:category, tags: [global_cat_tag], allow_global_tags: true) }
  fab!(:required) do
    Fabricate(
      :category,
      tag_groups: [req_group],
      allow_global_tags: true,
      category_required_tag_groups: [
        CategoryRequiredTagGroup.new(tag_group: req_group, min_count: 1),
      ],
    )
  end

  # The first required group still short of its minimum narrows the input, so the order matters.
  fab!(:first_required) { Fabricate(:tag_group, tags: [Fabricate(:tag, name: "first-req")]) }
  fab!(:second_required) { Fabricate(:tag_group, tags: [Fabricate(:tag, name: "second-req")]) }
  fab!(:two_required) do
    Fabricate(
      :category,
      tag_groups: [first_required, second_required],
      category_required_tag_groups: [
        CategoryRequiredTagGroup.new(tag_group: second_required, min_count: 1, order: 2),
        CategoryRequiredTagGroup.new(tag_group: first_required, min_count: 1, order: 1),
      ],
    )
  end

  before { SiteSetting.tagging_enabled = true }

  def usable_names(guardian, category: nil, held: [], term: nil)
    filter = { category: category&.id, held: held.presence, term: }
    described_class
      .collection(:applicable)
      .all({ filter: filter.compact, page: { size: 100 } }, guardian:)
      .records
      .map { it.record.name }
  end

  def allowed_names(guardian, category: nil, held: [], term: nil)
    DiscourseTagging.filter_allowed_tags(
      guardian,
      for_input: true,
      category:,
      selected_tag_ids: held,
      term:,
    ).map(&:name)
  end

  describe "the applicable collection" do
    it "offers a regular user only the tags they may apply outside any category" do
      expect(usable_names(user.guardian)).to contain_exactly(
        "plain",
        "parent",
        "shared",
        "linux",
        "mac",
      )
    end

    it "offers the children of a held parent, and leaves out the rest of a held one-per-topic group" do
      expect(usable_names(user.guardian, held: [parent.id, linux.id])).to contain_exactly(
        "plain",
        "child",
        "shared",
        "split",
      )
    end

    it "offers only the missing required tags in a category that requires a group" do
      expect(usable_names(user.guardian, category: required)).to contain_exactly(
        "req-one",
        "req-two",
      )
    end

    it "treats a category the user cannot see as no category" do
      secret_category = Fabricate(:private_category, group: Fabricate(:group), tags: [cat_only])

      expect(usable_names(user.guardian, category: secret_category)).to match_array(
        usable_names(user.guardian),
      )
    end

    it "finds an exact name only among the tags the user may apply" do
      exact_names =
        [plain, readonly_tag].map do |tag|
          described_class
            .collection(:applicable)
            .all({ filter: { name: tag.name.upcase } }, guardian: user.guardian)
            .records
            .map { it.record.name }
        end

      expect(exact_names).to eq([["plain"], []])
    end

    it "agrees with filter_allowed_tags for every guardian, category, held set and term" do
      guardians = {
        "anonymous" => Guardian.new,
        "user" => user.guardian,
        "moderator" => moderator.guardian,
        "admin" => admin.guardian,
      }
      categories = [nil, open_category, restricted, restricted_global, required, two_required]
      held_sets = [[], [parent.id], [linux.id], [req_one.id], [shared.id, cat_only.id]]
      terms = [nil, "a", "req", "linux"]

      mismatches =
        guardians
          .to_a
          .product(categories, held_sets, terms)
          .filter_map do |(label, guardian), category, held, term|
            expected = allowed_names(guardian, category:, held:, term:)
            actual = usable_names(guardian, category:, held:, term:)
            next if expected.sort == actual.sort

            {
              guardian: label,
              category: category&.name,
              held: Tag.where(id: held).pluck(:name),
              term:,
              missing: expected - actual,
              extra: actual - expected,
            }
          end

      expect(mismatches).to eq([])
    end

    # A fresh guardian per read, as each request builds one. A signed-in user's guardian reads the
    # categories it may see in two queries, which both the visibility scope and the category input
    # need; the category then costs one query with its restrictions and required groups.
    it "reads the tags in one query, plus one for the category when the request names one" do
      read = ->(person, filter) do
        described_class
          .collection(:applicable)
          .all({ filter:, page: { size: 5 } }, guardian: Guardian.new(person))
          .records
          .to_a
      end
      counts =
        {
          "user" => [user, {}],
          "user in a restricted category" => [user, { category: restricted.id }],
          "user in a required category, holding tags" => [
            user,
            { category: required.id, held: [linux.id, parent.id] },
          ],
          "admin" => [admin, {}],
          "admin in a restricted category" => [admin, { category: restricted.id }],
        }.transform_values do |(person, filter)|
          read.call(person, filter)
          track_sql_queries { read.call(person, filter) }.size
        end

      expect(counts).to eq(
        "user" => 3,
        "user in a restricted category" => 4,
        "user in a required category, holding tags" => 4,
        "admin" => 1,
        "admin in a restricted category" => 4,
      )
    end
  end

  describe "filtering by category" do
    it "agrees with filter_allowed_tags outside of input for every guardian and category" do
      guardians = {
        "anonymous" => Guardian.new,
        "user" => user.guardian,
        "admin" => admin.guardian,
      }

      mismatches =
        guardians
          .to_a
          .product([open_category, restricted, restricted_global, required])
          .filter_map do |(label, guardian), category|
            expected = DiscourseTagging.filter_allowed_tags(guardian, category:).map(&:name)
            actual =
              described_class
                .all({ filter: { category: category.id }, page: { size: 100 } }, guardian:)
                .records
                .map { it.record.name }
            next if expected.sort == actual.sort

            {
              guardian: label,
              category: category.name,
              missing: expected - actual,
              extra: actual - expected,
            }
          end

      expect(mismatches).to eq([])
    end
  end
end
