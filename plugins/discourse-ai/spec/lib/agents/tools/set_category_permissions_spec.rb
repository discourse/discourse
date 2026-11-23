# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::SetCategoryPermissions do
  fab!(:llm_model)
  fab!(:bot_user, :admin)
  fab!(:admin)
  fab!(:category)
  fab!(:group) { Fabricate(:group, name: "volunteers") }

  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  let(:conversation) do
    Fabricate(:private_message_topic, user: admin, recipient: Discourse.system_user)
  end
  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, topic: conversation) }
  let(:full) { CategoryGroup.permission_types[:full] }
  let(:readonly) { CategoryGroup.permission_types[:readonly] }
  let(:create_post) { CategoryGroup.permission_types[:create_post] }

  include_context "with AI bot enabled"

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  it "rejects shared conversations without disclosing private category permissions" do
    category.set_permissions(volunteers: :full)
    category.save!
    shared_dm = Fabricate(:direct_message_channel, users: [admin, Fabricate(:user)])
    shared_pm = Fabricate(:private_message_topic, user: admin, recipient: Fabricate(:user))
    contexts = [
      DiscourseAi::Agents::BotContext.new(user: admin, channel_id: Fabricate(:chat_channel).id),
      DiscourseAi::Agents::BotContext.new(user: admin, channel_id: shared_dm.id),
      DiscourseAi::Agents::BotContext.new(user: admin, topic: shared_pm),
      DiscourseAi::Agents::BotContext.new(user: admin, topic: Fabricate(:topic)),
    ]

    contexts.each do |shared_context|
      category_tool =
        described_class.new(
          { category_id: category.id, see_groups: ["staff"], reason: "Restrict" },
          bot_user:,
          llm:,
          context: shared_context,
        )

      expect(described_class.available_for_context?(shared_context)).to eq(false)
      expect(category_tool.invoke[:status]).to eq("error")
      expect(category_tool.approval_changes).to eq([])
      expect(category_tool.approval_title).not_to include(category.name)
      expect(category_tool.approval_details).not_to include(category.name, group.name)
    end
    expect(category.reload.category_groups.pluck(:group_id)).to eq([group.id])
  end

  it "makes a public category private to the given groups" do
    result =
      tool(
        category_id: category.id,
        create_reply_see_groups: ["Volunteers"],
        see_groups: ["@staff"],
        reason: "Volunteers only",
      ).invoke

    expect(result[:status]).to eq("success")
    category.reload
    expect(category.read_restricted).to eq(true)
    expect(category.category_groups.pluck(:group_id, :permission_type)).to contain_exactly(
      [group.id, full],
      [Group::AUTO_GROUPS[:staff], readonly],
    )
  end

  it "makes a private category public again" do
    category.set_permissions(volunteers: :full)
    category.save!

    result =
      tool(
        category_id: category.id,
        create_reply_see_groups: ["everyone"],
        reason: "Open up",
      ).invoke

    expect(result[:status]).to eq("success")
    category.reload
    expect(category.read_restricted).to eq(false)
    expect(category.category_groups).to be_empty
  end

  it "logs the permission change attributed to the context user" do
    tool(category_id: category.id, reply_see_groups: ["volunteers"], reason: "Audit").invoke

    log =
      UserHistory.find_by(
        acting_user_id: admin.id,
        action: UserHistory.actions[:change_category_settings],
        subject: "permissions",
      )
    expect(log.previous_value).to eq({ "everyone" => full }.to_json)
    expect(log.new_value).to eq({ "volunteers" => create_post }.to_json)
  end

  it "previews the current and proposed access without applying it" do
    category_tool =
      tool(
        category_id: category.id,
        create_reply_see_groups: ["volunteers"],
        see_groups: ["trust_level_1"],
        reason: "Restrict",
      )

    expect(category_tool.validation_error).to be_nil
    expect(category_tool.approval_changes).to eq(
      [
        { label: "volunteers:", before: "No access", after: "Create, reply, see" },
        { label: "trust_level_1:", before: "No access", after: "See" },
        { label: "everyone:", before: "Create, reply, see", after: "No access" },
      ],
    )
    expect(category_tool.approval_details.split("\n\n")).to eq(
      [
        "Changing `volunteers` from No access → Create, reply, see",
        "Changing `trust_level_1` from No access → See",
        "Changing `everyone` from Create, reply, see → No access",
        "The category becomes private. Only the listed groups and administrators will be able to see it.",
      ],
    )
    expect(category_tool.approval_question).to eq("Do you want to make this category private?")
    expect(category.reload.read_restricted).to eq(false)
  end

  it "links a private category by name, since the bot user can't resolve its hashtag" do
    category.update!(name: "Board *room*")
    category.set_permissions(volunteers: :full)
    category.save!

    title = tool(category_id: category.id, see_groups: ["staff"], reason: "Restrict").approval_title
    cooked = Nokogiri::HTML5.fragment(Chat::Message.cook(title, user_id: Fabricate(:user).id))

    link = cooked.at_css("a")
    expect(link["href"]).to eq(category.url)
    expect(link.text).to eq("Board *room*")
  end

  it "previews additional groups without additional queries" do
    groups = Fabricate.times(5, :group)
    single_group_tool = tool(category_id: category.id, see_groups: [group.name], reason: "Restrict")
    many_groups_tool =
      tool(
        category_id: category.id,
        see_groups: [group.name, *groups.map(&:name)],
        reason: "Restrict",
      )

    single_group_queries = track_sql_queries { single_group_tool.approval_changes }
    many_groups_queries = track_sql_queries { many_groups_tool.approval_changes }

    expect(many_groups_queries.size).to eq(single_group_queries.size)
  end

  it "only lists groups whose access changes" do
    category.set_permissions(volunteers: :full, staff: :full)
    category.save!

    category_tool =
      tool(
        category_id: category.id,
        create_reply_see_groups: ["volunteers"],
        see_groups: ["staff"],
        reason: "Staff only read",
      )

    expect(category_tool.approval_changes).to eq(
      [{ label: "staff:", before: "Create, reply, see", after: "See" }],
    )
    expect(category_tool.approval_question).to eq(
      "Do you want to change who can access this category?",
    )
  end

  it "describes a category only administrators can see" do
    category.update_columns(read_restricted: true)

    category_tool =
      tool(category_id: category.id, see_groups: ["everyone"], reason: "Let everyone read")

    expect(category_tool.approval_changes).to eq(
      [{ label: "everyone:", before: "No access", after: "See" }],
    )
    expect(category_tool.approval_details).to eq("Changing `everyone` from No access → See")
  end

  it "rejects unknown groups and lists available ones" do
    error =
      tool(
        category_id: category.id,
        create_reply_see_groups: ["nonexistent"],
        reason: "Typo",
      ).validation_error

    expect(error[:status]).to eq("error")
    expect(error[:error]).to include("nonexistent", "volunteers")
  end

  context "when a moderator manages categories" do
    fab!(:moderator)
    fab!(:hidden_group) do
      Fabricate(:group, name: "board", visibility_level: Group.visibility_levels[:owners])
    end

    let(:conversation) do
      Fabricate(:private_message_topic, user: moderator, recipient: Discourse.system_user)
    end
    let(:context) { DiscourseAi::Agents::BotContext.new(user: moderator, topic: conversation) }

    before { SiteSetting.moderators_manage_categories = true }

    it "neither uses nor suggests groups hidden from them" do
      error =
        tool(
          category_id: category.id,
          create_reply_see_groups: ["board"],
          reason: "Board only",
        ).validation_error

      expect(error[:error]).to include("board", "volunteers")
      expect(error[:error]).not_to match(/Available groups include:.*\bboard\b/)
      expect(category.reload.read_restricted).to eq(false)
    end

    it "can keep a hidden group the category already includes" do
      category.set_permissions(board: :full)
      category.save!
      moderator.groups << hidden_group

      result =
        tool(
          category_id: category.id,
          create_reply_see_groups: ["board"],
          see_groups: ["volunteers"],
          reason: "Let volunteers read",
        ).invoke

      expect(result[:status]).to eq("success")
      expect(category.reload.category_groups.pluck(:group_id, :permission_type)).to contain_exactly(
        [hidden_group.id, full],
        [group.id, readonly],
      )
    end

    it "can use groups visible to them" do
      result =
        tool(
          category_id: category.id,
          create_reply_see_groups: ["volunteers"],
          reason: "Volunteers only",
        ).invoke

      expect(result[:status]).to eq("success")
      expect(category.reload.category_groups.pluck(:group_id)).to eq([group.id])
    end
  end

  it "rejects a group listed at more than one level" do
    error =
      tool(
        category_id: category.id,
        create_reply_see_groups: ["volunteers"],
        see_groups: ["Volunteers"],
        reason: "Conflict",
      ).validation_error

    expect(error[:error]).to include("more than once")
  end

  it "rejects a request without any groups" do
    error = tool(category_id: category.id, see_groups: [" "], reason: "Empty").validation_error

    expect(error[:error]).to include("At least one group")
  end

  it "rejects permissions the category already has" do
    error =
      tool(
        category_id: category.id,
        create_reply_see_groups: ["everyone"],
        reason: "Repeat",
      ).validation_error

    expect(error[:error]).to include("already has these permissions")
  end

  it "rejects subcategory permissions that conflict with its parent" do
    category.set_permissions(volunteers: :full)
    category.save!
    subcategory = Fabricate(:private_category, group:, parent_category: category)

    error =
      tool(
        category_id: subcategory.id,
        create_reply_see_groups: ["everyone"],
        reason: "Open up",
      ).validation_error

    expect(error[:status]).to eq("error")
    expect(subcategory.reload.read_restricted).to eq(true)
  end

  it "rejects the uncategorized category" do
    uncategorized = Category.find(SiteSetting.uncategorized_category_id)

    error =
      tool(category_id: uncategorized.id, see_groups: ["staff"], reason: "Hide it").validation_error

    expect(error[:error]).to include("uncategorized")
  end

  it "returns an error when the context user cannot edit the category" do
    user = Fabricate(:user)
    topic = Fabricate(:private_message_topic, user:, recipient: Discourse.system_user)
    context = DiscourseAi::Agents::BotContext.new(user:, topic:)
    result =
      described_class.new(
        { category_id: category.id, see_groups: ["staff"], reason: "Nope" },
        bot_user: bot_user,
        llm: llm,
        context: context,
      ).invoke

    expect(result[:status]).to eq("error")
    expect(category.reload.read_restricted).to eq(false)
  end

  describe "admin assistant access" do
    let(:requests) { [] }
    let(:modifier) do
      lambda do |decision, request|
        requests << request
        if request.feature == :category_permissions
          decision.deny!("Not available on this site.")
        else
          decision
        end
      end
    end
    let(:plugin) { Plugin::Instance.new }

    before do
      DiscoursePluginRegistry.register_modifier(plugin, :admin_assistant_feature_access, &modifier)
    end

    after do
      DiscoursePluginRegistry.unregister_modifier(
        plugin,
        :admin_assistant_feature_access,
        &modifier
      )
    end

    it "refuses the change when a plugin denies category permissions" do
      result = tool(category_id: category.id, see_groups: ["staff"], reason: "Restrict").invoke

      expect(result).to eq({ status: "error", error: "Not available on this site." })
      expect(requests.map { |request| [request.feature, request.phase] }).to eq(
        [%i[category_permissions request]],
      )
      expect(category.reload.read_restricted).to eq(false)
    end

    it "refuses the change when the plugin denies it at approval time" do
      context.reviewable_id = 123
      result = tool(category_id: category.id, see_groups: ["staff"], reason: "Restrict").invoke

      expect(result).to eq({ status: "error", error: "Not available on this site." })
      expect(requests.map { |request| [request.feature, request.phase] }).to eq(
        [%i[category_permissions approval]],
      )
      expect(category.reload.read_restricted).to eq(false)
    end
  end
end
