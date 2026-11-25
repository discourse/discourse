# frozen_string_literal: true

RSpec.describe DiscourseMcp::Tools::SetThemeCode do
  fab!(:admin)
  fab!(:user)
  fab!(:theme) { Fabricate(:theme, user: admin, component: true) }

  def request_context(actor = admin)
    instance_double(
      DiscourseMcp::RequestContext,
      guardian: actor.guardian,
      user_id: actor.id,
      user: actor,
      content_policy: DiscourseMcp::ContentPolicy.new([]),
    )
  end

  def revision
    DiscourseMcp::Tools::ThemeSupport.code_revision(theme.reload)
  end

  describe ".call" do
    it "writes canonical files, checks compilation, and rejects stale edits" do
      original = revision
      css = ".d-header { background: red; }"
      javascript = <<~JS
        import { apiInitializer } from "discourse/lib/api";
        export default apiInitializer((api) => {
          document.documentElement.dataset.mcpTest = 'ok';
        });
      JS
      result =
        described_class.call(
          arguments: {
            "theme_id" => theme.id,
            "expected_code_revision" => original,
            "css" => css,
            "javascript" => javascript,
          },
          request_context: request_context,
        )[
          :structuredContent
        ]

      expect(result[:theme][:theme_fields]).to contain_exactly(
        include(name: "scss", target: "common", value: css, file_path: "common/common.scss"),
        include(
          name: described_class::JAVASCRIPT_NAME,
          target: "extra_js",
          value: javascript,
          file_path: "javascripts/discourse/api-initializers/mcp-theme-code.js",
        ),
      )
      expect(result[:verification]).to include(
        saved: true,
        compilation_checked: true,
        browser_verified: false,
      )
      expect(result[:theme][:code_revision]).not_to eq(original)
      expect(theme.reload.javascript_cache.content).to include(
        "discourse/api-initializers/mcp-theme-code",
      )

      expect do
        described_class.call(
          arguments: {
            "theme_id" => theme.id,
            "expected_code_revision" => original,
            "css" => ".d-header { color: blue; }",
          },
          request_context: request_context,
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.theme_code_stale"))
      expect(theme.reload.theme_fields.find_by(name: "scss").value).to eq(css)
    end

    it "rolls back invalid CSS and JavaScript" do
      original = revision
      [{ "css" => "body { color: red;" }, { "javascript" => "const = ;" }].each do |code|
        expect do
          described_class.call(
            arguments: { "theme_id" => theme.id, "expected_code_revision" => original }.merge(code),
            request_context: request_context,
          )
        end.to raise_error(DiscourseMcp::ToolError)
        expect(theme.reload.theme_fields).to be_empty
        expect(revision).to eq(original)
      end
    end

    it "requires administrator access" do
      expect do
        described_class.call(arguments: {}, request_context: request_context(user))
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "reports compiler details when another file breaks the JavaScript bundle" do
      theme.set_field(target: :extra_js, name: "broken.js", value: "const = ;")
      theme.save!
      original = revision

      expect do
        described_class.call(
          arguments: {
            "theme_id" => theme.id,
            "expected_code_revision" => original,
            "javascript" => "const valid = true;",
          },
          request_context: request_context,
        )
      end.to raise_error(DiscourseMcp::ToolError) { |error|
        expect(error.message).to include("bundle failed compilation", "Compile error:", "broken.js")
      }
      expect(revision).to eq(original)
    end

    it "counts non-ASCII code by characters consistently with the schema" do
      css = "/*#{"é" * 32_768}*/"
      described_class.call(
        arguments: {
          "theme_id" => theme.id,
          "expected_code_revision" => revision,
          "css" => css,
        },
        request_context: request_context,
      )
      expect(theme.reload.theme_fields.find_by(name: "scss").value).to eq(css)

      expect do
        described_class.call(
          arguments: {
            "theme_id" => theme.id,
            "expected_code_revision" => revision,
            "css" => "é" * 65_537,
          },
          request_context: request_context,
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.theme_code_too_large"))
      expect(theme.reload.theme_fields.find_by(name: "scss").value).to eq(css)
    end

    it "rejects unknown field types and null values without deleting saved code" do
      css = "body { color: red; }"
      theme.set_field(target: :common, name: "scss", value: css)
      theme.save!
      [
        { "name" => "unused", "target" => "common", "type" => "unknown", "value" => css },
        { "name" => "scss", "target" => "common", "value" => nil },
      ].each do |field|
        expect do
          DiscourseMcp::Tools::UpdateTheme.call(
            arguments: {
              "theme_id" => theme.id,
              "theme_fields" => [field],
            },
            request_context: request_context,
          )
        end.to raise_error(DiscourseMcp::ToolError) { |error|
          expect(error.message).to include(
            field["type"] ? "Unknown theme field type" : "string value",
          )
        }
        expect(theme.reload.theme_fields.find_by(name: "scss").value).to eq(css)
      end
    end

    it "preserves saved code and compiled JavaScript when either edited file fails compilation" do
      theme.set_field(target: :common, name: "scss", value: "body { color: red; }")
      theme.set_field(
        target: :extra_js,
        name: described_class::JAVASCRIPT_NAME,
        value: "document.documentElement.dataset.saved = 'yes';",
      )
      theme.save!
      original = revision
      original_fields = theme.theme_fields.order(:id).pluck(:target_id, :name, :value)
      original_javascript = theme.javascript_cache.content
      original_audit_count = UserHistory.where(action: UserHistory.actions[:change_theme]).count

      [
        { "css" => "body { color: red;", "javascript" => "const updated = true;" },
        { "css" => "body { color: blue; }", "javascript" => "const = ;" },
      ].each do |code|
        expect do
          described_class.call(
            arguments: { "theme_id" => theme.id, "expected_code_revision" => original }.merge(code),
            request_context: request_context,
          )
        end.to raise_error(DiscourseMcp::ToolError)

        expect(theme.reload.theme_fields.order(:id).pluck(:target_id, :name, :value)).to eq(
          original_fields,
        )
        expect(theme.javascript_cache.content).to eq(original_javascript)
        expect(revision).to eq(original)
        expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(
          original_audit_count,
        )
      end
    end

    it "preserves omitted files and removes explicitly emptied files" do
      theme.set_field(target: :common, name: "scss", value: "body { color: red; }")
      theme.set_field(
        target: :extra_js,
        name: described_class::JAVASCRIPT_NAME,
        value: "const saved = true;",
      )
      theme.save!

      described_class.call(
        arguments: {
          "theme_id" => theme.id,
          "expected_code_revision" => revision,
          "css" => "",
        },
        request_context: request_context,
      )

      expect(theme.reload.theme_fields.pluck(:name, :value)).to eq(
        [[described_class::JAVASCRIPT_NAME, "const saved = true;"]],
      )
      described_class.call(
        arguments: {
          "theme_id" => theme.id,
          "expected_code_revision" => revision,
          "javascript" => "",
        },
        request_context: request_context,
      )
      expect(theme.reload.theme_fields).to be_empty
      expect(theme.javascript_cache).to be_nil
    end

    it "rejects unused field locations while allowing cleanup of existing invalid fields" do
      arguments = {
        "theme_id" => theme.id,
        "theme_fields" => [
          {
            "name" => "disco-scss",
            "target" => "common",
            "type" => "scss",
            "value" => "body { color: red; }",
          },
        ],
      }
      expect do
        DiscourseMcp::Tools::UpdateTheme.call(
          arguments: arguments,
          request_context: request_context,
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.theme_field_location_invalid"))
      theme.set_field(
        target: :common,
        name: "disco-scss",
        type: :scss,
        value: "body { color: red; }",
      )
      theme.save!
      arguments["theme_fields"].first["value"] = ""
      DiscourseMcp::Tools::UpdateTheme.call(arguments: arguments, request_context: request_context)
      expect(theme.reload.theme_fields).to be_empty
    end
  end
end
