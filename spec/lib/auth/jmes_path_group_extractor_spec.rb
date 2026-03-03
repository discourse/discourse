# frozen_string_literal: true

RSpec.describe Auth::JmesPathGroupExtractor do
  fab!(:user)

  before { SiteSetting.jmespath_group_mapping_enabled = true }

  def extract_groups(auth_token, rules)
    SiteSetting.jmes_group_mapping_rules_by_attributes = JSON.generate(rules)
    described_class.extract_groups(auth_token)
  end

  def group_names(groups)
    groups.map { |g| g[:name] }
  end

  let(:google_auth_token) do
    {
      provider: "google_oauth2",
      uid: "123456789",
      info: {
        email: "engineers@company.com",
        name: "John Doe",
      },
      extra: {
        raw_info: {
          email_verified: true,
          hd: "company.com",
        },
      },
    }
  end

  let(:oidc_auth_token) do
    {
      provider: "oidc",
      uid: "user123",
      info: {
        email: "user@company.com",
        name: "John Doe",
      },
      extra: {
        raw_info: {
          email_verified: true,
          role: "admin",
          groups: %w[admins developers],
          custom_claims: {
            discourse_role: "moderator",
          },
        },
      },
    }
  end

  let(:saml_auth_token) do
    {
      provider: "saml",
      uid: "user@company.com",
      info: {
        email: "user@company.com",
        name: "John Doe",
      },
      extra: {
        response_object: {
          attributes: {
            "email" => ["user@company.com"],
            "memberOf" => %w[
              CN=Admins,OU=Groups,DC=company,DC=com
              CN=Developers,OU=Groups,DC=company,DC=com
            ],
          },
        },
      },
    }
  end

  describe ".extract_groups" do
    context "when disabled" do
      before { SiteSetting.jmespath_group_mapping_enabled = false }

      it "returns empty array" do
        groups =
          extract_groups(
            google_auth_token,
            [
              {
                provider: "*",
                expression: "info.email == 'user@company.com'",
                groups: ["Members"],
              },
            ],
          )

        expect(groups).to eq([])
      end
    end

    context "with Google OAuth" do
      it "extracts enabled and wildcard rules only" do
        groups =
          extract_groups(
            google_auth_token,
            [
              {
                provider: "google_oauth2",
                expression: "contains(info.email, 'admins@company.com')",
                groups: ["Administrators"],
                enabled: true,
              },
              {
                provider: "google_oauth2",
                expression: "contains(info.email, 'engineers@company.com')",
                groups: %w[Engineers Employees],
                enabled: true,
              },
              {
                provider: "*",
                expression: "ends_with(info.email, '@company.com')",
                groups: ["WildcardGroup"],
                enabled: true,
              },
              {
                provider: "google_oauth2",
                expression: "contains(info.email, 'engineers@company.com')",
                groups: %w[DisabledRuleGroup],
                enabled: false,
              },
            ],
          )

        expect(group_names(groups)).to contain_exactly("Engineers", "Employees", "WildcardGroup")
      end

      it "defaults missing provider to wildcard" do
        groups =
          extract_groups(
            google_auth_token,
            [{ expression: "info.email == 'engineers@company.com'", groups: ["Members"] }],
          )

        expect(group_names(groups)).to eq(["Members"])
      end
    end

    context "with OIDC" do
      it "extracts role from custom claims" do
        groups =
          extract_groups(
            oidc_auth_token,
            [
              {
                provider: "oidc",
                expression: "extra.raw_info.custom_claims.discourse_role == 'moderator'",
                groups: ["Moderators"],
              },
            ],
          )

        expect(group_names(groups)).to eq(["Moderators"])
      end

      it "returns empty when expression evaluates false" do
        groups =
          extract_groups(
            oidc_auth_token,
            [
              {
                provider: "oidc",
                expression: "extra.raw_info.role == 'superadmin'",
                groups: ["SuperAdministrators"],
              },
            ],
          )

        expect(groups).to be_empty
      end
    end

    context "with SAML" do
      it "extracts multiple memberOf matches" do
        groups =
          extract_groups(
            saml_auth_token,
            [
              {
                provider: "saml",
                expression:
                  "length(extra.response_object.attributes.memberOf[?starts_with(@, 'CN=Admins,')]) > `0`",
                groups: ["Administrators"],
              },
              {
                provider: "saml",
                expression:
                  "length(extra.response_object.attributes.memberOf[?starts_with(@, 'CN=Developers,')]) > `0`",
                groups: ["Developers"],
              },
            ],
          )

        expect(group_names(groups)).to contain_exactly("Administrators", "Developers")
      end
    end

    context "with invalid rules" do
      it "handles invalid JMESPath" do
        groups =
          extract_groups(
            google_auth_token,
            [
              {
                provider: "google_oauth2",
                expression: "this is not valid jmespath!!!",
                groups: ["Administrators"],
              },
            ],
          )

        expect(groups).to be_empty
      end

      it "handles null and empty results as falsy" do
        groups =
          extract_groups(
            google_auth_token,
            [
              {
                provider: "google_oauth2",
                expression: "extra.nonexistent.field",
                groups: ["Administrators"],
              },
            ],
          )

        expect(groups).to be_empty
      end
    end

    context "with duplicate groups" do
      it "deduplicates group names across rules" do
        groups =
          extract_groups(
            google_auth_token,
            [
              {
                provider: "google_oauth2",
                expression: "info.email == 'engineers@company.com'",
                groups: ["Members"],
              },
              {
                provider: "google_oauth2",
                expression: "extra.raw_info.hd == 'company.com'",
                groups: %w[Members Employees],
              },
            ],
          )

        expect(group_names(groups)).to contain_exactly("Members", "Employees")
      end
    end
  end
end
