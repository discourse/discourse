# frozen_string_literal: true

require_relative "../../../../script/bulk_import/discourse_merger/merger"

RSpec.describe BulkImport::DiscourseMerge::ContentPolicy do
  let(:incoming) do
    (
      BulkImport::DiscourseMerge::ContentInventory::BOTH.keys +
        BulkImport::DiscourseMerge::ContentInventory::SOURCE.keys
    )
      .index_with { [] }
      .merge(
        "admins" => [],
        "authorities" => [],
        "historical_users" => [],
        "permalink_posts" => [],
        "source_settings" => {
        },
      )
  end
  let(:existing) do
    BulkImport::DiscourseMerge::ContentInventory::BOTH
      .keys
      .index_with { [] }
      .merge(
        "admins" => [],
        "settings" => {
          "local_passwords" => true,
          "moderation" => true,
          "draft_category" => 60,
          "draft_groups" => [47],
          "admin_bypass" => true,
          "publishing" => true,
          "anonymous_publishing" => true,
        },
      )
  end
  let(:site) do
    {
      "groups" => [],
      "group_memberships" => [],
      "categories" => [],
      "topics" => [],
      "grants" => [],
    }
  end
  let(:source) do
    site.merge(
      "database" => "incoming",
      "content" => incoming,
      "importable_user_ids" => [1, 2, 3, 4],
      "account_matches" => [{ "source_user_id" => 1, "destination_user_id" => 21 }],
    )
  end
  let(:destination) { site.merge("database" => "destination", "content" => existing) }
  let(:config) do
    instance_double(
      BulkImport::DiscourseMerge::Configuration,
      namespace: "harbor",
      data: {
        "source_url" => "https://old.example",
        "destination_url" => "https://new.example",
      },
    )
  end

  def decisions(topics: [], groups: [], categories: [], actions: [])
    described_class.new(
      config,
      { "source" => source, "destination" => destination },
      categories,
      actions,
      groups,
      topics,
    ).build
  end

  it "maps profile answers through compatible definitions and protects the destination's directory and existing accounts" do
    field = {
      "id" => "1",
      "name" => "Trade",
      "description" => "Workshop trade",
      "field_type_enum" => "3",
      "show_on_profile" => "t",
    }
    serial = field.merge("id" => "2", "name" => "Serial", "field_type_enum" => "0")
    private_field = field.merge("id" => "3", "name" => "Locker")
    incoming["user_fields"] = [field, serial, private_field]
    existing["user_fields"] = [
      field.merge("id" => "2"),
      private_field.merge("id" => "1", "listed" => "t"),
    ]
    option = { "id" => "5", "user_field_id" => "1", "value" => "Rigger" }
    incoming["user_field_options"] = [option, option.merge("id" => "6", "value" => "Pilot")]
    existing["user_field_options"] = [option.merge("id" => "9", "user_field_id" => "2")]
    answer = { "id" => "10", "name" => "user_field_1", "user_id" => "2", "choice" => "Rigger" }
    incoming["user_custom_fields"] = [
      answer,
      answer.merge("id" => "11", "choice" => "Pilot"),
      answer.merge("id" => "12", "user_id" => "1"),
      answer.merge("id" => "13", "name" => "user_field_3"),
    ]

    plan = decisions
    expect(plan["user_fields"].pluck("action")).to eq(%w[reused copied skipped])
    expect(plan["user_fields"].first.fetch("target")).to eq(2)
    expect(plan["user_fields"].second.fetch("values")).to include(
      "searchable" => false,
      "show_on_signup" => false,
      "requirement" => 0,
    )
    expect(plan["user_field_options"].pluck("action")).to eq(%w[reused skipped])
    expect(plan["user_custom_fields"].pluck("action")).to eq(%w[copied skipped skipped skipped])
    expect(plan["user_custom_fields"].first.dig("refs", "name")).to eq(["user_fields", 1])
  end

  it "preserves a draft only while its room, publication category and audience can be preserved" do
    draft = { "id" => "8", "category_id" => "10", "topic_id" => "40" }
    incoming["shared_drafts"] = [draft]
    incoming["source_settings"] = {
      "shared_drafts_category" => "11",
      "shared_drafts_allowed_groups" => "45",
    }
    source["topics"] = [{ "id" => "40", "category_id" => "11" }]
    source["categories"] = [{ "id" => "11", "read_restricted" => "f" }]
    destination["categories"] = [{ "id" => "60", "read_restricted" => "f" }]
    membership = { "user_id" => "1", "group_id" => "45" }
    source["group_memberships"] = [membership]
    destination["group_memberships"] = [{ "user_id" => "21", "group_id" => "47" }]
    groups = [{ "source_group_id" => 45, "action" => "reuse", "destination_group_id" => 47 }]
    categories = [{ "key" => "destination:60" }, { "key" => "new:2" }]
    actions = [{ "source_category_id" => 10, "destination_key" => "new:2", "action" => "copy" }]
    topic = { "source_topic_id" => 40, "action" => "copy_shared_draft" }
    build = -> do
      decisions(groups: groups, categories: categories, actions: actions, topics: [topic])
    end
    expect(build.call.fetch("shared_drafts").sole.dig("refs", "category_id")).to eq(
      %w[category_keys new:2],
    )
    expect(topic.fetch("destination_key")).to eq("destination:60")
    existing.fetch("settings")["draft_groups"] = [Group::AUTO_GROUPS[:logged_in_users]]
    existing["member_ids"] = [21, 73]
    expect(build.call.fetch("shared_drafts").sole.fetch("action")).to eq("skipped")
    existing.fetch("settings")["draft_groups"] = [47]
    topic["action"] = "copy_shared_draft"
    destination["categories"].first["read_restricted"] = "t"
    destination["grants"] = [
      { "category_id" => "60", "group_id" => Group::AUTO_GROUPS[:logged_in_users].to_s },
    ]
    destination["group_memberships"] << { "user_id" => "73", "group_id" => "47" }
    expect(build.call.fetch("shared_drafts").sole.fetch("action")).to eq("skipped")
    destination["group_memberships"].pop
    topic["action"] = "copy_shared_draft"
    existing.fetch("admins") << 73
    expect(build.call.fetch("shared_drafts").sole.fetch("action")).to eq("skipped")
    expect(topic).to include("action" => "exclude", "destination_key" => nil)
  end

  it "withholds matched and incompatible passwords and preserves the mapped personal message senders" do
    row = {
      "id" => "10",
      "user_id" => "2",
      "password_algorithm" => UserPassword::TARGET_PASSWORD_ALGORITHM,
    }
    incoming["user_passwords"] = [
      row,
      row.merge("id" => "11", "user_id" => "1"),
      row.merge("id" => "12", "security_key" => "t"),
      row.merge("id" => "13", "password_algorithm" => "obsolete"),
    ]
    incoming["allowed_pm_users"] = [
      { "id" => "1", "user_id" => "2", "allowed_pm_user_id" => "1" },
      { "id" => "2", "user_id" => "1", "allowed_pm_user_id" => "2" },
    ]
    plan = decisions
    expect(plan.fetch("user_passwords").pluck("action")).to eq(%w[copied skipped skipped skipped])
    expect(plan.fetch("allowed_pm_users").pluck("action")).to eq(%w[copied skipped])
    expect(plan.fetch("allowed_pm_users").first.dig("refs", "allowed_pm_user_id")).to eq(
      ["users", 1],
    )
    existing.fetch("settings")["local_passwords"] = false
    expect(decisions.fetch("user_passwords").pluck("action").uniq).to eq(["skipped"])
  end

  it "keeps occupied routes and translations, and uses destination artwork for a conflicting emoji in preserved HTML" do
    topic = {
      "source_topic_id" => 71,
      "action" => "copy_discussion",
      "destination_key" => "destination:60",
      "source_state" => {
        "visible" => true,
      },
    }
    source["topics"] = [{ "id" => "71", "category_id" => "10" }]
    source["categories"] = [{ "id" => "10", "read_restricted" => "f" }]
    incoming.fetch("source_settings")["enable_page_publishing"] = "t"
    incoming["published_pages"] = [
      { "id" => "3", "slug" => "manual", "topic_id" => "71", "public" => "f" },
    ]
    existing["published_pages"] = [
      { "id" => "2", "slug" => "manual", "topic_id" => "71", "public" => "t" },
    ]
    alias_row = { "id" => "1", "url" => "help/install", "topic_id" => "71" }
    incoming["permalinks"] = [
      alias_row,
      alias_row.merge("id" => "2", "url" => "t/old/71"),
      alias_row.merge("id" => "3", "url" => "guides/original"),
      alias_row.merge("id" => "4", "url" => "/guides/original"),
    ]
    existing["permalinks"] = [alias_row.merge("user_id" => "5", "topic_id" => nil)]
    translation = { "id" => "3", "category_id" => "10", "locale" => "fr" }
    incoming["category_localizations"] = [
      translation,
      translation.merge("id" => "4", "locale" => "de"),
    ]
    existing["category_localizations"] = [translation.merge("category_id" => "60")]
    emoji = {
      "id" => "1",
      "name" => "workshop_logo",
      "sha1" => "bbb",
      "url" => "/uploads/default/logo.png",
    }
    existing["custom_emojis"] = [emoji]
    incoming["custom_emojis"] = [emoji.merge("sha1" => "aaa")]
    categories = [
      { "key" => "destination:60", "destination_category_id" => 60, "access" => "public" },
    ]
    actions = [
      { "source_category_id" => 10, "action" => "reuse", "destination_key" => "destination:60" },
    ]

    plan = decisions(topics: [topic], categories: categories, actions: actions)
    expect(plan.fetch("published_pages").sole).to include(
      "action" => "skipped",
      "retained_topic" => 71,
    )
    expect(plan.fetch("permalinks").pluck("action")).to eq(%w[skipped skipped copied reused])
    expect(plan.fetch("permalinks").last.fetch("source_target")).to eq(3)
    expect(plan.fetch("category_localizations").pluck("action")).to eq(%w[reused copied])
    name, url = plan.fetch("custom_emojis").sole.fetch("render")
    references =
      BulkImport::DiscourseMerge::References.new(
        source_host: "old.example",
        destination_host: "new.example",
        topics: {
        },
        categories: {
        },
        emoji_urls: {
          name => url,
        },
      )
    html = %(<p><img class="emoji" alt=":#{name}:" src="/old.png"><img src="/other.png"></p>)
    expect(references.rewrite(html, cooked: true)).to include(url, 'src="/other.png"')
    expect(references.rewrite("<code>#{html}</code>", cooked: true)).to eq("<code>#{html}</code>")
  end

  it "distinguishes populated unknown tables, deliberate omissions and existing blockers in preflight" do
    connection = ActiveRecord::Base.connection.raw_connection
    %w[merger_unknown merger_blocked merger_empty].each do |name|
      connection.exec("CREATE TABLE #{name} (id integer)")
    end
    connection.exec("INSERT INTO merger_unknown VALUES (1)")
    connection.exec("INSERT INTO merger_blocked VALUES (1)")
    coverage =
      BulkImport::DiscourseMerge::ContentInventory.coverage(
        connection,
        {
          "unsupported_entities" => {
            "merger_blocked" => 1,
          },
          "pending_entities" => {
          },
          "omitted_plugin_entities" => {
          },
        },
      )
    expect(coverage).to include(
      "merger_unknown" => "unrecognized and omitted",
      "merger_blocked" => "blocked",
      "schema_migrations" => "intentionally omitted",
    )
    expect(coverage).not_to have_key("merger_empty")
  end
end
