# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::SiteSettingUpdate::V1 do
  fab!(:admin)
  fab!(:moderator)

  describe ".load_options_context" do
    def options_for(filter: nil)
      context = DiscourseWorkflows::LoadOptionsContext.new(method_name: "site_settings", filter:)
      described_class.load_options_context(context)
    end

    it "lists settings an admin could change in the admin UI, sorted by name" do
      names = options_for.map { |option| option[:id] }

      expect(names).to include("title", "site_description", "enable_badges")
      expect(names).to eq(names.sort)
      expect(options_for.first).to eq(id: names.first, name: names.first)
    end

    it "excludes hidden, secret, and shadowed settings" do
      SiteSetting.shadowed_settings << :site_description
      names = options_for.map { |option| option[:id] }

      expect(names).not_to include(*SiteSetting.hidden_settings.map(&:to_s))
      expect(names).not_to include(*SiteSetting.secret_settings.map(&:to_s))
      expect(names).not_to include("site_description")
    ensure
      SiteSetting.shadowed_settings.delete(:site_description)
    end

    it "filters by the typed text" do
      expect(options_for(filter: "site_desc")).to include(
        { id: "site_description", name: "site_description" },
      )
      expect(options_for(filter: "site_desc")).not_to include({ id: "title", name: "title" })
    end
  end

  describe "#execute" do
    let(:item) { { "json" => { "year" => "2026" } } }
    let(:history_scope) { UserHistory.where(action: UserHistory.actions[:change_site_setting]) }

    it "updates a string setting, logs it, and reports the change" do
      SiteSetting.site_description = "Old description"
      config = { "name" => "site_description", "value" => "=Community since {{ $json.year }}" }

      expect { @result = execute_node(configuration: config, item: item) }.to change {
        history_scope.count
      }.by(1)

      expect(SiteSetting.site_description).to eq("Community since 2026")
      expect(@result).to eq(
        "name" => "site_description",
        "value" => "Community since 2026",
        "previous_value" => "Old description",
        "changed" => true,
      )
      expect(history_scope.last).to have_attributes(
        acting_user_id: Discourse.system_user.id,
        subject: "site_description",
        previous_value: "Old description",
        new_value: "Community since 2026",
      )
    end

    it "coerces typed values the way the admin UI does" do
      SiteSetting.enable_badges = true
      config = { "name" => "enable_badges", "value" => "false", "actor_username" => admin.username }

      result = execute_node(configuration: config, item: item)

      expect(SiteSetting.enable_badges).to eq(false)
      expect(result).to include("value" => "false", "previous_value" => "true", "changed" => true)
      expect(history_scope.last.acting_user_id).to eq(admin.id)
    end

    it "reports no change and writes no log when the value is already set" do
      SiteSetting.site_description = "Same"
      config = { "name" => "site_description", "value" => "Same" }

      expect { @result = execute_node(configuration: config, item: item) }.not_to change {
        history_scope.count
      }

      expect(@result).to include("changed" => false)
    end

    it "surfaces core validation errors as node errors" do
      config = { "name" => "min_password_length", "value" => "not a number" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        /min_password_length/,
      )
    end

    it "rejects unknown settings" do
      config = { "name" => "definitely_not_a_setting", "value" => "x" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        /Unknown site setting/,
      )
    end

    it "rejects secret settings" do
      secret_name = SiteSetting.secret_settings.first.to_s

      expect {
        execute_node(configuration: { "name" => secret_name, "value" => "x" }, item: item)
      }.to raise_error(DiscourseWorkflows::NodeError, /holds a secret/)
    end

    it "rejects hidden settings" do
      hidden_name = SiteSetting.hidden_settings.first.to_s

      expect {
        execute_node(configuration: { "name" => hidden_name, "value" => "x" }, item: item)
      }.to raise_error(DiscourseWorkflows::NodeError)
    end

    it "requires the actor to be an admin" do
      config = {
        "name" => "site_description",
        "value" => "Nope",
        "actor_username" => moderator.username,
      }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        /must be an admin/,
      )
      expect(SiteSetting.site_description).not_to eq("Nope")
    end

    it "does not let the anonymous actor change settings" do
      config = { "name" => "site_description", "value" => "Nope", "actor_username" => "anonymous" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        /must be an admin/,
      )
    end
  end
end
