# frozen_string_literal: true

# Run with: bin/rails runner script/seed_tag_search_demo.rb
class TagSearchDemoSeed
  PASSWORD = "TagLabDemoPass123!"
  REVIEWER_GROUP_NAME = "tag-lab-reviewers"

  def run
    admin = account("tag-lab-admin", admin: true)
    member = account("tag-lab-member")
    reviewer = account("tag-lab-reviewer")

    reviewer_group = Group.find_or_create_by!(name: REVIEWER_GROUP_NAME)
    reviewer_group.add(reviewer)

    SiteSetting.tagging_enabled = true
    SiteSetting.prioritize_recently_used_tags = true
    SiteSetting.pm_tags_allowed_for_groups = Group::AUTO_GROUPS[:admins].to_s
    SiteSetting.display_personal_messages_tag_counts = true
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "en|ja"

    everyone = { "everyone" => :full }
    lab = category("Tag Search Lab", "tag-search-lab", admin, permissions: everyone)
    private_category =
      category(
        "Tag Search Private",
        "tag-search-private",
        admin,
        permissions: {
          REVIEWER_GROUP_NAME => :full,
        },
      )
    strict_category =
      category(
        "Tag Search Strict",
        "tag-search-strict",
        admin,
        permissions: everyone,
        allow_global_tags: false,
      )
    required_category =
      category("Tag Search Required", "tag-search-required", admin, permissions: everyone)
    limited_category =
      category("Tag Search Limited", "tag-search-limited", admin, permissions: everyone)
    many_categories =
      (1..4).map do |number|
        category(
          "Tag Search Scope #{number}",
          "tag-search-scope-#{number}",
          admin,
          permissions: everyone,
        )
      end

    alpha = tag("taglab-alpha")
    beta = tag("taglab-beta")
    popular = tag("taglab-popular")
    recent_a = tag("taglab-recent-a")
    recent_b = tag("taglab-recent-b")
    exclusive_a = tag("taglab-exclusive-a")
    exclusive_b = tag("taglab-exclusive-b")
    parent = tag("taglab-parent")
    child = tag("taglab-child")
    restricted = tag("taglab-limited")
    many = tag("taglab-many")
    private_tag = tag("taglab-private")
    public_and_private = tag("taglab-pubpriv")
    private_group_tag = tag("taglab-group-private")
    tag("taglab-global")
    strict_tag = tag("taglab-strict")
    hidden_tag = tag("taglab-hidden")
    hidden_selected = tag("taglab-hidesel")
    public_sibling = tag("taglab-sibling")
    synonym_target = tag("taglab-target")
    tag("taglab-syn", target_tag: synonym_target)
    has_synonyms = tag("taglab-has-synonyms")
    tag("taglab-has-alt", target_tag: has_synonyms)
    secret_target = tag("taglab-secret-target")
    tag("taglab-secret-syn", target_tag: secret_target)
    orphan = tag("taglab-orphan")
    app_tag = tag("taglab-app")
    hosting_a = tag("taglab-hosting-a")
    hosting_b = tag("taglab-hosting-b")
    tag("taglab-linux")
    pm_tag = tag("taglab-pm")
    localized = tag("taglab-strategy", locale: "en")

    tag_group("Tag Search Exclusive", [exclusive_a, exclusive_b], one_per_topic: true)
    tag_group("Tag Search Hidden Exclusive", [hidden_selected, public_sibling], one_per_topic: true)
    tag_group("Tag Search Parent", [child], parent_tag: parent)
    tag_group("Tag Search Hidden Parent", [orphan], parent_tag: secret_target)
    private_group = tag_group("Tag Search Private Group", [private_group_tag])
    CategoryTagGroup.find_or_create_by!(category: private_category, tag_group: private_group)
    tag_group(
      "Tag Search Hidden Group",
      [hidden_tag],
      permissions: {
        REVIEWER_GROUP_NAME => :full,
      },
    )
    app_group = tag_group("Tag Search Apps", [app_tag])
    hosting_group = tag_group("Tag Search Hosting", [hosting_a, hosting_b])
    strict_group = tag_group("Tag Search Strict Group", [strict_tag])
    CategoryTagGroup.find_or_create_by!(category: strict_category, tag_group: strict_group)

    [[app_group, 1, 1], [hosting_group, 2, 2]].each do |tag_group_record, min_count, order|
      CategoryRequiredTagGroup.find_or_initialize_by(
        category: required_category,
        tag_group: tag_group_record,
      ).update!(min_count:, order:)
    end

    CategoryTag.find_or_create_by!(category: limited_category, tag: restricted)
    many_categories.each do |category_record|
      CategoryTag.find_or_create_by!(category: category_record, tag: many)
    end
    CategoryTag.find_or_create_by!(category: private_category, tag: private_tag)
    CategoryTag.find_or_create_by!(category: private_category, tag: public_and_private)
    CategoryTag.find_or_create_by!(category: lab, tag: public_and_private)
    CategoryTag.find_or_create_by!(category: private_category, tag: hidden_selected)
    CategoryTag.find_or_create_by!(category: private_category, tag: secret_target)
    TagLocalization.find_or_create_by!(tag: localized, locale: "ja") { |row| row.name = "戦略" }

    topic(member, lab, "Tag Lab Recent A", [recent_a])
    topic(member, lab, "Tag Lab Recent B", [recent_b])
    topic(admin, lab, "Tag Lab Alpha Example", [alpha])
    topic(admin, lab, "Tag Lab Beta Example", [beta])
    3.times { |index| topic(admin, lab, "Tag Lab Popular Example #{index + 1}", [popular]) }

    unless Topic.exists?(title: "Tag Lab PM Only Example", user_id: admin.id)
      pm =
        TopicCreator.create(
          admin,
          Guardian.new(admin),
          title: "Tag Lab PM Only Example",
          raw: "This private message gives taglab-pm a real PM-only count.",
          archetype: Archetype.private_message,
          target_usernames: member.username,
          tags: [pm_tag.name],
        )
      unless pm&.persisted?
        raise "Could not create PM example: #{pm&.errors&.full_messages&.join(", ")}"
      end
    end

    puts "Tag Search demo data is ready."
    puts "Accounts (password for each: #{PASSWORD}):"
    puts "  admin:    tag-lab-admin"
    puts "  member:   tag-lab-member"
    puts "  reviewer: tag-lab-reviewer (in #{REVIEWER_GROUP_NAME})"
    puts "Categories:"
    [
      lab,
      required_category,
      strict_category,
      limited_category,
      private_category,
      *many_categories,
    ].each { |record| puts "  /c/#{record.slug}/#{record.id}  #{record.name}" }
    puts "Try taglab- in the composer; select taglab-exclusive-a before searching taglab-exclusive-b."
    puts "In Tag Search Required, select taglab-app and both hosting tags; taglab-linux shows the remaining requirement."
    puts "Use the member/reviewer/admin accounts to compare private and hidden tags; taglab-pubpriv also has a public scope."
    puts "Switch locale to Japanese for taglab-strategy; taglab-pm has a real private-message topic count."
  end

  private

  def account(username, admin: false)
    user = User.find_or_initialize_by(username:)
    attributes = {
      email: "#{username}@example.test",
      name: username.tr("-", " ").split.map(&:capitalize).join(" "),
      active: true,
    }
    attributes[:password] = PASSWORD if user.new_record?
    user.assign_attributes(attributes)
    user.save!
    user.email_tokens.update_all(confirmed: true)
    user.activate if user.email_tokens.where(email: user.email, confirmed: true).none?
    user.update!(active: true) unless user.active?
    user.grant_admin! if admin && !user.admin?
    user.change_trust_level!(TrustLevel[1]) if !admin && user.trust_level < TrustLevel[1]
    # The demo member needs several topics to exercise recent-tag ordering.
    user.update_columns(created_at: 2.days.ago) if !admin && user.created_at > 24.hours.ago
    user
  end

  def category(name, slug, admin, permissions:, allow_global_tags: true)
    attributes = {
      name:,
      slug:,
      color: "5269d8",
      text_color: "ffffff",
      permissions:,
      allow_global_tags:,
    }
    existing = Category.find_by(slug:)
    return existing.tap { |record| record.update!(attributes) } if existing

    record = CategoryCreator.create(Guardian.new(admin), attributes)
    unless record.persisted?
      raise "Could not create #{name}: #{record.errors.full_messages.join(", ")}"
    end
    record
  end

  def tag(name, **attributes)
    Tag
      .find_or_initialize_by(name:)
      .tap do |record|
        record.assign_attributes(attributes)
        record.save! if record.new_record? || record.has_changes_to_save?
      end
  end

  def tag_group(name, tags, one_per_topic: false, parent_tag: nil, permissions: nil)
    group = TagGroup.find_or_initialize_by(name:)
    group.one_per_topic = one_per_topic
    group.parent_tag = parent_tag
    group.permissions = permissions if permissions
    group.save!
    group.tags = tags
    group
  end

  def topic(user, category, title, tags)
    return Topic.find_by!(title:, user_id: user.id) if Topic.exists?(title:, user_id: user.id)

    record =
      TopicCreator.create(
        user,
        Guardian.new(user),
        title:,
        raw: "Demo topic for manually checking tag search behavior.",
        category: category.id,
        tags: tags.map(&:name),
      )
    unless record&.persisted?
      raise "Could not create #{title}: #{record.errors.full_messages.join(", ")}"
    end
    record
  end
end

TagSearchDemoSeed.new.run
