# frozen_string_literal: true

RSpec.describe Auth::JmesPathGroupExtractor do
  fab!(:user)

  before { SiteSetting.jmespath_group_mapping_enabled = true }

  def extract_groups(payload, rules)
    SiteSetting.jmes_group_mapping_rules_by_attributes = JSON.generate(rules)
    described_class.extract_groups_from_discourse_connect(payload)
  end

  def group_names(groups)
    groups.map { |g| g[:name] }
  end

  let(:discourse_connect_payload) do
    {
      external_id: "user123",
      email: "user@company.com",
      name: "John Doe",
      username: "johndoe",
      "custom.department": "Engineering",
      "custom.plan": "enterprise",
      "custom.role": "admin",
    }
  end

  let(:payload_without_custom_fields) do
    {
      external_id: "user456",
      email: "basic@example.com",
      name: "Basic User",
      username: "basicuser",
    }
  end

  describe ".extract_groups_from_discourse_connect" do
    context "when disabled" do
      before { SiteSetting.jmespath_group_mapping_enabled = false }

      it "returns empty array" do
        groups =
          extract_groups(
            discourse_connect_payload,
            [
              {
                provider: "discourse_connect",
                expression: "email == 'user@company.com'",
                groups: ["Members"],
              },
            ],
          )

        expect(groups).to eq([])
      end
    end

    context "with custom fields" do
      it "matches custom plan" do
        groups =
          extract_groups(
            discourse_connect_payload,
            [
              {
                provider: "discourse_connect",
                expression: "custom_fields.plan == 'enterprise'",
                groups: ["EnterpriseUsers"],
              },
            ],
          )

        expect(group_names(groups)).to eq(["EnterpriseUsers"])
      end
    end

    context "with multiple rules" do
      it "combines groups from multiple matching rules" do
        groups =
          extract_groups(
            discourse_connect_payload,
            [
              {
                provider: "discourse_connect",
                expression: "custom_fields.department == 'Engineering'",
                groups: ["Engineers"],
              },
              {
                provider: "discourse_connect",
                expression: "custom_fields.plan == 'enterprise'",
                groups: ["EnterpriseUsers"],
              },
              {
                provider: "discourse_connect",
                expression: "ends_with(email, '@company.com')",
                groups: ["CompanyMembers"],
              },
              {
                provider: "discourse_connect",
                expression: "custom_fields.plan == 'enterprise'",
                groups: ["DisabledRuleGroup"],
                enabled: false,
              },
            ],
          )

        expect(group_names(groups)).to contain_exactly(
          "Engineers",
          "EnterpriseUsers",
          "CompanyMembers",
        )
      end

      it "adds multiple groups from a single rule" do
        groups =
          extract_groups(
            discourse_connect_payload,
            [
              {
                provider: "discourse_connect",
                expression: "custom_fields.role == 'admin'",
                groups: %w[Administrators Staff Moderators],
              },
            ],
          )

        expect(group_names(groups)).to contain_exactly("Administrators", "Staff", "Moderators")
      end
    end

    context "with provider matching" do
      it "supports wildcard provider and missing provider to wildcard" do
        groups =
          extract_groups(
            discourse_connect_payload,
            [
              { provider: "*", expression: "email == 'user@company.com'", groups: ["Members"] },
              { expression: "email == 'user@company.com'", groups: ["NoProviderMembers"] },
            ],
          )

        expect(group_names(groups)).to eq(%w[Members NoProviderMembers])
      end

      it "skips non-matching providers" do
        groups =
          extract_groups(
            discourse_connect_payload,
            [
              {
                provider: "google_oauth2",
                expression: "email == 'user@company.com'",
                groups: ["Members"],
              },
            ],
          )

        expect(groups).to be_empty
      end
    end

    context "with invalid rules" do
      it "handles invalid JMESPath expression" do
        groups =
          extract_groups(
            discourse_connect_payload,
            [
              {
                provider: "discourse_connect",
                expression: "this is not valid jmespath!!!",
                groups: ["Administrators"],
              },
            ],
          )

        expect(groups).to be_empty
      end

      it "treats null result as falsy" do
        groups =
          extract_groups(
            discourse_connect_payload,
            [
              {
                provider: "discourse_connect",
                expression: "custom_fields.nonexistent_field",
                groups: ["Administrators"],
              },
            ],
          )

        expect(groups).to be_empty
      end

      it "treats false result as falsy" do
        groups =
          extract_groups(
            discourse_connect_payload,
            [
              {
                provider: "discourse_connect",
                expression: "custom_fields.department == 'Marketing'",
                groups: ["Marketers"],
              },
            ],
          )

        expect(groups).to be_empty
      end
    end

    context "with duplicate groups" do
      it "deduplicates groups" do
        groups =
          extract_groups(
            discourse_connect_payload,
            [
              {
                provider: "discourse_connect",
                expression: "email == 'user@company.com'",
                groups: ["Members"],
              },
              {
                provider: "discourse_connect",
                expression: "custom_fields.plan == 'enterprise'",
                groups: %w[Members EnterpriseUsers],
              },
            ],
          )

        expect(group_names(groups)).to contain_exactly("Members", "EnterpriseUsers")
      end
    end
  end
end
