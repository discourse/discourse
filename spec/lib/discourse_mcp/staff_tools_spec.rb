# frozen_string_literal: true

describe DiscourseMcp::Tools do
  def request_context(user)
    instance_double(
      DiscourseMcp::RequestContext,
      user:,
      user_id: user.id,
      guardian: user.guardian,
    ).tap do |context|
      allow(context).to receive(:has_scopes?).and_return(true)
      allow(context).to receive(:ensure_scopes!)
    end
  end

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:moderator)
  fab!(:admin)

  describe "moderation reads" do
    fab!(:reviewable, :reviewable_flagged_post)

    it "requires access to the review queue" do
      tools = {
        DiscourseMcp::Tools::GetReviewQueueCount => {
        },
        DiscourseMcp::Tools::ListReviewables => {
        },
        DiscourseMcp::Tools::ListReviewableTopics => {
        },
        DiscourseMcp::Tools::GetReviewable => {
          "reviewable_id" => reviewable.id,
        },
      }

      tools.each do |tool, arguments|
        expect { tool.call(arguments:, request_context: request_context(user)) }.to raise_error(
          Discourse::InvalidAccess,
        )
      end
    end

    it "only returns reviewables visible to a category moderator" do
      SiteSetting.enable_category_group_moderation = true
      group = Fabricate(:group)
      group.add(user)
      allowed_category = Fabricate(:category)
      other_category = Fabricate(:category)
      Fabricate(:category_moderation_group, category: allowed_category, group:)
      allowed =
        Fabricate(
          :reviewable_flagged_post,
          category: allowed_category,
          topic: Fabricate(:topic, category: allowed_category),
        )
      Fabricate(
        :reviewable_flagged_post,
        category: other_category,
        topic: Fabricate(:topic, category: other_category),
      )

      result =
        DiscourseMcp::Tools::ListReviewables.call(
          arguments: {
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      expect(result[:reviewables].pluck(:id)).to eq([allowed.id])
      expect(result[:meta]).to include(total: 1, returned: 1, has_more: false)
    end

    it "returns queue count, topic signals, and detail for staff" do
      context = request_context(moderator)

      count =
        DiscourseMcp::Tools::GetReviewQueueCount.call(
          arguments: {
          },
          request_context: context,
        ).fetch(:structuredContent)
      topics =
        DiscourseMcp::Tools::ListReviewableTopics.call(
          arguments: {
          },
          request_context: context,
        ).fetch(:structuredContent)
      detail =
        DiscourseMcp::Tools::GetReviewable.call(
          arguments: {
            "reviewable_id" => reviewable.id,
          },
          request_context: context,
        ).fetch(:structuredContent)

      expect(count).to include(count: 1, unit: "pending_reviewable_queue_items")
      expect(topics[:topics].pluck(:id)).to include(reviewable.topic_id)
      expect(detail[:reviewable]).to include(id: reviewable.id, version: reviewable.version)
      expect(detail[:actions]).to be_present
    end

    it "paginates topic signals before serializing them" do
      other_reviewable = Fabricate(:reviewable_flagged_post)

      first_page =
        DiscourseMcp::Tools::ListReviewableTopics.call(
          arguments: {
            "offset" => 0,
            "limit" => 1,
          },
          request_context: request_context(moderator),
        ).fetch(:structuredContent)
      second_page =
        DiscourseMcp::Tools::ListReviewableTopics.call(
          arguments: {
            "offset" => 1,
            "limit" => 1,
          },
          request_context: request_context(moderator),
        ).fetch(:structuredContent)

      expect(first_page[:topics].pluck(:id) + second_page[:topics].pluck(:id)).to contain_exactly(
        reviewable.topic_id,
        other_reviewable.topic_id,
      )
      expect(first_page[:meta]).to include(returned: 1, total: 2, has_more: true, next_offset: 1)
      expect(second_page[:meta]).to include(
        returned: 1,
        total: 2,
        has_more: false,
        next_offset: nil,
      )
    end
  end

  describe DiscourseMcp::Tools::GetUserModerationSummary do
    it "returns the native staff counters and rejects non-staff" do
      expect do
        described_class.call(
          arguments: {
            "username" => user.username,
          },
          request_context: request_context(user),
        )
      end.to raise_error(Discourse::InvalidAccess)

      result =
        described_class.call(
          arguments: {
            "username" => user.username,
          },
          request_context: request_context(moderator),
        ).fetch(:structuredContent)

      expect(result).to include(
        username: user.username,
        deleted_posts: user.number_of_deleted_posts,
        flags_received: user.number_of_flags,
        flags_given: user.number_of_flags_given,
      )
    end
  end

  describe DiscourseMcp::Tools::GetPostRevision do
    fab!(:post) { Fabricate(:post, user:) }

    before do
      SiteSetting.editing_grace_period = 0
      PostRevisor.new(post).revise!(user, raw: "revised post body")
    end

    it "uses review-queue and post-revision permissions" do
      expect do
        described_class.call(
          arguments: {
            "post_id" => post.id,
          },
          request_context: request_context(user),
        )
      end.to raise_error(Discourse::InvalidAccess)

      result =
        described_class.call(
          arguments: {
            "post_id" => post.id,
            "revision" => "latest",
          },
          request_context: request_context(moderator),
        ).fetch(:structuredContent)

      expect(result).to include(post_id: post.id, current_revision: 2)
      expect(result[:body_changes]).to be_present
    end

    it "returns revisions for deleted content visible to the reviewer" do
      post.trash!(moderator)

      deleted_post_result =
        described_class.call(
          arguments: {
            "post_id" => post.id,
            "revision" => "latest",
          },
          request_context: request_context(moderator),
        ).fetch(:structuredContent)

      post.recover!
      post.topic.trash!(moderator)
      deleted_topic_result =
        described_class.call(
          arguments: {
            "post_id" => post.id,
            "revision" => "latest",
          },
          request_context: request_context(moderator),
        ).fetch(:structuredContent)

      expect([deleted_post_result, deleted_topic_result]).to all(
        include(post_id: post.id, current_revision: 2),
      )
    end

    it "hides a deleted post outside a category moderator's scope" do
      SiteSetting.enable_category_group_moderation = true
      group = Fabricate(:group)
      group.add(user)
      moderated_category = Fabricate(:category)
      Fabricate(:category_moderation_group, category: moderated_category, group: group)
      Fabricate(:reviewable_flagged_post, category: moderated_category)
      post.trash!(moderator)

      expect do
        described_class.call(
          arguments: {
            "post_id" => post.id,
            "revision" => "latest",
          },
          request_context: request_context(user),
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.post_not_found"))
    end
  end

  describe DiscourseMcp::Tools::PerformReviewableAction do
    fab!(:reviewable, :reviewable_queued_post)

    it "requires queue access, a current version, and a currently available action" do
      arguments = {
        "reviewable_id" => reviewable.id,
        "action_id" => "reject_post",
        "expected_version" => reviewable.version,
        "confirm" => true,
      }

      expect do
        described_class.call(arguments:, request_context: request_context(user))
      end.to raise_error(Discourse::InvalidAccess)

      expect do
        described_class.call(
          arguments: arguments.merge("expected_version" => reviewable.version + 1),
          request_context: request_context(moderator),
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.reviewable_conflict"))

      result =
        described_class.call(arguments:, request_context: request_context(moderator)).fetch(
          :structuredContent,
        )

      expect(result).to include(success: true, reviewable_id: reviewable.id)
      expect(reviewable.reload).to be_rejected
    end

    it "fails closed for missing confirmation, claims, and extra fields" do
      base_arguments = {
        "reviewable_id" => reviewable.id,
        "action_id" => "reject_post",
        "expected_version" => reviewable.version,
      }
      context = request_context(moderator)

      expect do
        described_class.call(arguments: base_arguments, request_context: context)
      end.to raise_error(
        DiscourseMcp::ToolError,
        I18n.t("mcp.errors.reviewable_confirmation_required"),
      )

      expect do
        described_class.call(
          arguments:
            base_arguments.merge(
              "confirm" => true,
              "additional_fields" => {
                "unadvertised_field" => true,
              },
            ),
          request_context: context,
        )
      end.to raise_error(DiscourseMcp::ToolError, /unadvertised_field/)

      SiteSetting.reviewable_claiming = "required"
      expect do
        described_class.call(
          arguments: base_arguments.merge("confirm" => true),
          request_context: context,
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("reviewables.must_claim"))
      expect(reviewable.reload).to be_pending
    end
  end

  describe DiscourseMcp::Tools::ListSiteSettings do
    it "is admin-only and masks secret values" do
      expect do
        described_class.call(arguments: {}, request_context: request_context(moderator))
      end.to raise_error(Discourse::InvalidAccess)

      secret_name = "google_oauth2_client_secret"
      SiteSetting.google_oauth2_client_secret = "not returned by MCP"
      result =
        described_class.call(
          arguments: {
            "names" => [secret_name],
          },
          request_context: request_context(admin),
        ).fetch(:structuredContent)
      setting = result[:site_settings].sole

      expect(setting).to include(setting: secret_name, secret: true, value: nil, default: nil)
      expect(result.to_json).not_to include("not returned by MCP")
    end
  end

  describe DiscourseMcp::Tools::UpdateSiteSetting do
    it "is admin-only, checks the current value, and uses the audited update service" do
      arguments = {
        "setting" => "title",
        "operation" => "set",
        "value" => "A new MCP title",
        "expected_current_value" => SiteSetting.title,
        "confirm_change" => true,
      }

      expect do
        described_class.call(arguments:, request_context: request_context(moderator))
      end.to raise_error(Discourse::InvalidAccess)

      expect do
        described_class.call(
          arguments: arguments.merge("expected_current_value" => "stale title"),
          request_context: request_context(admin),
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.site_setting_conflict"))

      expect do
        described_class.call(arguments:, request_context: request_context(admin))
      end.to change {
        UserHistory.where(action: UserHistory.actions[:change_site_setting], subject: "title").count
      }.by(1)

      expect(SiteSetting.title).to eq("A new MCP title")
    end

    it "returns the value normalized by the site-setting update service" do
      result =
        described_class.call(
          arguments: {
            "setting" => "max_image_size_kb",
            "operation" => "set",
            "value" => "8zf843",
            "expected_current_value" => SiteSetting.max_image_size_kb,
            "confirm_change" => true,
          },
          request_context: request_context(admin),
        ).fetch(:structuredContent)

      expect(SiteSetting.max_image_size_kb).to eq(8843)
      expect(result.dig(:after, :value)).to eq("8843")
    end

    it "rejects a concurrent update that uses a stale current value" do
      current_title = SiteSetting.title
      first_update_started = Queue.new
      second_update_started = Queue.new
      release_first_update = Queue.new
      call_count = 0
      call_count_mutex = Mutex.new

      allow(SiteSetting::Update).to receive(:call).and_wrap_original do |original, *args, **kwargs|
        current_call = call_count_mutex.synchronize { call_count += 1 }
        if current_call == 1
          first_update_started << true
          release_first_update.pop
        elsif current_call == 2
          second_update_started << true
        end
        original.call(*args, **kwargs)
      end

      outcomes = Queue.new
      update =
        lambda do |value|
          described_class.call(
            arguments: {
              "setting" => "title",
              "operation" => "set",
              "value" => value,
              "expected_current_value" => current_title,
              "confirm_change" => true,
            },
            request_context: request_context(admin),
          )
          outcomes << :success
        rescue => error
          outcomes << error
        end

      first_update = Thread.new { update.call("First concurrent title") }
      begin
        Timeout.timeout(5) { first_update_started.pop }
        second_update = Thread.new { update.call("Second concurrent title") }
        Timeout.timeout(5) { second_update_started.pop }
      ensure
        release_first_update << true
        first_update.join
        second_update&.join
      end

      results = 2.times.map { outcomes.pop }
      expect(results.grep(:success).length).to eq(1)
      expect(results.grep(DiscourseMcp::ToolError).map(&:message)).to eq(
        [I18n.t("mcp.errors.site_setting_conflict")],
      )
      expect(SiteSetting.title).to be_in(["First concurrent title", "Second concurrent title"])
    end

    it "rejects an MCP update when the admin UI changes the setting first" do
      current_title = SiteSetting.title
      mcp_update_started = Queue.new
      release_mcp_update = Queue.new

      allow(SiteSetting::Update).to receive(:call).and_wrap_original do |original, *args, **kwargs|
        if kwargs.dig(:options, :expected_values).present?
          mcp_update_started << true
          release_mcp_update.pop
        end
        original.call(*args, **kwargs)
      end

      outcome = Queue.new
      mcp_update =
        Thread.new do
          described_class.call(
            arguments: {
              "setting" => "title",
              "operation" => "set",
              "value" => "MCP title",
              "expected_current_value" => current_title,
              "confirm_change" => true,
            },
            request_context: request_context(admin),
          )
          outcome << :success
        rescue => error
          outcome << error
        end

      begin
        Timeout.timeout(5) { mcp_update_started.pop }
        admin_update =
          SiteSetting::Update.call(
            guardian: admin.guardian,
            params: {
              settings: [{ setting_name: "title", value: "Admin UI title" }],
            },
          )
      ensure
        release_mcp_update << true
        mcp_update.join
      end

      expect(admin_update).to be_success
      expect(outcome.pop).to be_a(DiscourseMcp::ToolError).and have_attributes(
              message: I18n.t("mcp.errors.site_setting_conflict"),
            )
      expect(SiteSetting.title).to eq("Admin UI title")
    end

    it "checks hidden site setting dependencies without exposing them" do
      SiteSetting.enable_local_logins_via_code = false

      expect do
        described_class.call(
          arguments: {
            "setting" => "enable_random_usernames",
            "operation" => "set",
            "value" => false,
            "expected_current_value" => SiteSetting.enable_random_usernames,
            "confirm_change" => true,
          },
          request_context: request_context(admin),
        )
      end.to raise_error(DiscourseMcp::ToolError, /enable_local_logins_via_code/)
    end

    it "updates a setting when its hidden dependencies are satisfied" do
      SiteSetting.enable_local_logins_via_code = true

      result =
        described_class.call(
          arguments: {
            "setting" => "enable_random_usernames",
            "operation" => "set",
            "value" => !SiteSetting.enable_random_usernames,
            "expected_current_value" => SiteSetting.enable_random_usernames,
            "confirm_change" => true,
          },
          request_context: request_context(admin),
        ).fetch(:structuredContent)

      expect(result).to include(updated: true, setting: "enable_random_usernames", verified: true)
    end

    it "refuses secret settings without exposing their value" do
      secret_name = "google_oauth2_client_secret"

      expect do
        described_class.call(
          arguments: {
            "setting" => secret_name,
            "operation" => "set",
            "value" => "replacement secret",
            "expected_current_value" => "unknown",
            "confirm_change" => true,
          },
          request_context: request_context(admin),
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.site_setting_sensitive"))
    end

    it "refuses setting types that the global update service cannot safely change" do
      setting =
        DiscourseMcp::Tools::ListSiteSettings
          .call(
            arguments: {
              "names" => ["enable_welcome_banner"],
            },
            request_context: request_context(admin),
          )
          .dig(:structuredContent, :site_settings)
          .sole

      expect(setting).to include(themeable: true, editable_by_this_tool: false)
      expect do
        described_class.call(
          arguments: {
            "setting" => "enable_welcome_banner",
            "operation" => "set",
            "value" => "false",
            "expected_current_value" => setting[:value],
            "confirm_change" => true,
          },
          request_context: request_context(admin),
        )
      end.to raise_error(
        DiscourseMcp::ToolError,
        I18n.t("mcp.errors.site_setting_type_unsupported"),
      )
    end

    it "requires confirmation even when called outside the protocol dispatcher" do
      expect do
        described_class.call(
          arguments: {
            "setting" => "title",
            "operation" => "set",
            "value" => "Not applied",
            "expected_current_value" => SiteSetting.title,
          },
          request_context: request_context(admin),
        )
      end.to raise_error(
        DiscourseMcp::ToolError,
        I18n.t("mcp.errors.site_setting_change_confirmation_required"),
      )
      expect(SiteSetting.title).not_to eq("Not applied")
    end
  end

  describe DiscourseMcp::Tools::CreateTheme do
    it "creates a theme with fields for an admin and rejects everyone else" do
      expect do
        described_class.call(
          arguments: {
            "name" => "MCP Theme",
            "user_selectable" => true,
            "theme_fields" => [
              { "name" => "header", "target" => "common", "value" => "<div>hello</div>" },
              { "name" => "scss", "target" => "desktop", "value" => "body { color: red; }" },
            ],
          },
          request_context: request_context(user),
        )
      end.to raise_error(Discourse::InvalidAccess)

      result =
        described_class.call(
          arguments: {
            "name" => "MCP Theme",
            "user_selectable" => true,
            "theme_fields" => [
              { "name" => "header", "target" => "common", "value" => "<div>hello</div>" },
              { "name" => "scss", "target" => "desktop", "value" => "body { color: red; }" },
            ],
          },
          request_context: request_context(admin),
        ).fetch(:structuredContent)

      theme = result[:theme]
      expect(theme).to include(
        name: "MCP Theme",
        user_selectable: true,
        component: false,
        default: false,
      )
      expect(theme[:id]).to be_present
      expect(theme[:theme_fields]).to contain_exactly(
        include(name: "header", target: "common", value: "<div>hello</div>"),
        include(name: "scss", target: "desktop", value: "body { color: red; }"),
      )
      expect(Theme.find(theme[:id])).to have_attributes(name: "MCP Theme", user_id: admin.id)
    end

    it "reports contract and model failures from the create service" do
      expect do
        described_class.call(arguments: { "name" => "" }, request_context: request_context(admin))
      end.to raise_error(DiscourseMcp::ToolError)

      expect do
        described_class.call(
          arguments: {
            "name" => "Bad component",
            "component" => true,
            "color_scheme_id" => Fabricate(:color_scheme).id,
          },
          request_context: request_context(admin),
        )
      end.to raise_error(DiscourseMcp::ToolError, /color/i)
    end

    it "blocks creation when remote themes are allowlisted" do
      GlobalSetting.stubs(:allowed_theme_repos).returns("https://github.com/discourse/sample-theme")

      expect do
        described_class.call(
          arguments: {
            "name" => "Blocked Theme",
          },
          request_context: request_context(admin),
        )
      end.to raise_error(Discourse::InvalidAccess)
    end
  end

  describe DiscourseMcp::Tools::UpdateTheme do
    fab!(:theme) { Fabricate(:theme, user: admin) }

    it "is admin-only" do
      expect do
        described_class.call(
          arguments: {
            "theme_id" => theme.id,
            "name" => "Renamed",
          },
          request_context: request_context(moderator),
        )
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "updates attributes and fields" do
      result =
        described_class.call(
          arguments: {
            "theme_id" => theme.id,
            "name" => "Renamed Theme",
            "user_selectable" => true,
            "enabled" => false,
            "theme_fields" => [
              { "name" => "header", "target" => "common", "value" => "<div>updated</div>" },
            ],
          },
          request_context: request_context(admin),
        ).fetch(:structuredContent)

      expect(result[:theme]).to include(
        id: theme.id,
        name: "Renamed Theme",
        user_selectable: true,
        enabled: false,
      )
      expect(result[:theme][:theme_fields]).to contain_exactly(
        include(name: "header", target: "common", value: "<div>updated</div>"),
      )
      expect(theme.reload).to have_attributes(
        name: "Renamed Theme",
        user_selectable: true,
        enabled: false,
      )
      expect(theme.theme_fields.find_by(name: "header").value).to eq("<div>updated</div>")
    end

    it "records component enable and disable actions with the acting admin" do
      component = Fabricate(:theme, component: true)
      freeze_time

      described_class.call(
        arguments: {
          "theme_id" => component.id,
          "enabled" => false,
        },
        request_context: request_context(admin),
      )

      expect(component.reload.disabled_by).to eq(admin)
      expect(component.disabled_at).to eq_time(Time.current)

      described_class.call(
        arguments: {
          "theme_id" => component.id,
          "enabled" => true,
        },
        request_context: request_context(admin),
      )

      expect(component.reload).to be_enabled
      expect(
        UserHistory.where(context: component.id.to_s).pluck(:action, :acting_user_id),
      ).to contain_exactly(
        [UserHistory.actions[:disable_theme_component], admin.id],
        [UserHistory.actions[:enable_theme_component], admin.id],
      )
    end

    it "clears a field when its value is blank" do
      theme.set_field(target: :common, name: "header", value: "<div>bye</div>")
      theme.save!

      result =
        described_class.call(
          arguments: {
            "theme_id" => theme.id,
            "theme_fields" => [{ "name" => "header", "target" => "common", "value" => "" }],
          },
          request_context: request_context(admin),
        ).fetch(:structuredContent)

      expect(result[:theme][:theme_fields]).to be_empty
      expect(theme.reload.theme_fields.find_by(name: "header")).to be_nil
    end

    it "requires at least one field to update" do
      expect do
        described_class.call(
          arguments: {
            "theme_id" => theme.id,
          },
          request_context: request_context(admin),
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.theme_update_required"))
    end

    it "reports a missing theme" do
      expect do
        described_class.call(
          arguments: {
            "theme_id" => 999_999,
            "name" => "Nope",
          },
          request_context: request_context(admin),
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.theme_not_found"))
    end

    it "rejects non-editable attributes on system themes" do
      system_theme = Theme.find(-1)

      expect do
        described_class.call(
          arguments: {
            "theme_id" => system_theme.id,
            "name" => "Renamed system theme",
          },
          request_context: request_context(admin),
        )
      end.to raise_error(Discourse::InvalidAccess)

      expect do
        described_class.call(
          arguments: {
            "theme_id" => system_theme.id,
            "enabled" => false,
          },
          request_context: request_context(admin),
        )
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "preserves component attributes when the requested default is invalid" do
      component = Fabricate(:theme, component: true)
      original_name = component.name
      original_default = SiteSetting.default_theme_id

      expect do
        described_class.call(
          arguments: {
            "theme_id" => component.id,
            "name" => "Not saved",
            "default" => true,
          },
          request_context: request_context(admin),
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("themes.errors.component_no_default"))

      expect(component.reload.name).to eq(original_name)
      expect(SiteSetting.default_theme_id).to eq(original_default)
    end

    it "rolls back component relationships when a later field assignment fails" do
      original_component = Fabricate(:theme, component: true)
      replacement_component = Fabricate(:theme, component: true)
      theme.update!(child_theme_ids: [original_component.id])

      expect do
        described_class.call(
          arguments: {
            "theme_id" => theme.id,
            "child_theme_ids" => [replacement_component.id],
            "theme_fields" => [
              { "name" => "unknown_field", "target" => "common", "value" => "content" },
            ],
          },
          request_context: request_context(admin),
        )
      end.to raise_error(DiscourseMcp::ToolError, /No type could be guessed/)

      expect(theme.reload.child_theme_ids).to contain_exactly(original_component.id)
    end

    it "sets and clears the default theme" do
      described_class.call(
        arguments: {
          "theme_id" => theme.id,
          "default" => true,
        },
        request_context: request_context(admin),
      )
      expect(theme.reload).to be_default
      expect(SiteSetting.default_theme_id).to eq(theme.id)

      described_class.call(
        arguments: {
          "theme_id" => theme.id,
          "default" => false,
        },
        request_context: request_context(admin),
      )
      expect(theme.reload).not_to be_default
      expect(SiteSetting.default_theme_id).not_to eq(theme.id)
    end
  end

  it "registers the selected tools under separate read and write scopes" do
    expected = {
      "discourse_get_review_queue_count" => [DiscourseMcp::Scopes::MODERATION_READ],
      "discourse_list_reviewables" => [DiscourseMcp::Scopes::MODERATION_READ],
      "discourse_list_reviewable_topics" => [DiscourseMcp::Scopes::MODERATION_READ],
      "discourse_get_reviewable" => [DiscourseMcp::Scopes::MODERATION_READ],
      "discourse_get_user_moderation_summary" => [DiscourseMcp::Scopes::MODERATION_READ],
      "discourse_get_post_revision" => [DiscourseMcp::Scopes::MODERATION_READ],
      "discourse_perform_reviewable_action" => [DiscourseMcp::Scopes::MODERATION_WRITE],
      "discourse_list_site_settings" => [DiscourseMcp::Scopes::SITE_SETTINGS_READ],
      "discourse_update_site_setting" => [DiscourseMcp::Scopes::SITE_SETTINGS_WRITE],
      "discourse_get_theme" => [DiscourseMcp::Scopes::THEMES_READ],
      "discourse_create_theme" => [DiscourseMcp::Scopes::THEMES_WRITE],
      "discourse_update_theme" => [DiscourseMcp::Scopes::THEMES_WRITE],
    }

    actual =
      expected.keys.to_h do |identifier|
        [identifier, DiscourseMcp.registry.find(:tool, identifier)&.required_scopes]
      end

    expect(actual).to eq(expected)
    expect(
      DiscourseMcp.registry.find(:tool, "discourse_perform_reviewable_action").annotations,
    ).to include("destructiveHint" => true, "openWorldHint" => true)
    expect(
      DiscourseMcp.registry.find(:tool, "discourse_update_site_setting").annotations,
    ).to include("destructiveHint" => true, "idempotentHint" => true, "openWorldHint" => true)

    schemas = DiscourseMcp.registry.all.map(&:input_schema)
    expect(schemas.to_json).not_to include('\\\\A', '\\\\z')
  end
end
