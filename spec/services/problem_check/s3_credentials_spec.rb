# frozen_string_literal: true

RSpec.describe ProblemCheck::S3Credentials do
  subject(:check) { described_class.new }

  describe ".call" do
    before do
      GlobalSetting.stubs(use_s3?: globally_enabled)
      GlobalSetting.stubs(s3_access_key_id: global_access_key_id)
      GlobalSetting.stubs(s3_secret_access_key: global_secret_access_key)
      SiteSetting.stubs(enable_s3_uploads?: locally_enabled)
      SiteSetting.stubs(s3_upload_bucket: bucket_name)
      SiteSetting.stubs(s3_access_key_id: access_key_id)
      SiteSetting.stubs(s3_secret_access_key: secret_access_key)
    end

    let(:globally_enabled) { false }
    let(:locally_enabled) { false }
    let(:bucket_name) { nil }
    let(:access_key_id) { nil }
    let(:secret_access_key) { nil }
    let(:global_access_key_id) { nil }
    let(:global_secret_access_key) { nil }

    context "when S3 is not enabled" do
      it { expect(check).to be_chill_about_it }
    end

    context "when S3 is globally enabled" do
      let(:globally_enabled) { true }

      context "with explicit credentials" do
        let(:access_key_id) { "AKIAIOSFODNN7EXAMPLE" }
        let(:secret_access_key) { "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" }

        it { expect(check).to be_chill_about_it }
      end

      context "without explicit credentials" do
        it do
          expect(check).to have_a_problem.with_priority("low").with_message(
            I18n.t("dashboard.problem.s3_credentials", base_path: ""),
          )
        end
      end

      context "with partial credentials (only access key)" do
        let(:access_key_id) { "AKIAIOSFODNN7EXAMPLE" }

        it do
          expect(check).to have_a_problem.with_priority("low").with_message(
            I18n.t("dashboard.problem.s3_credentials_partial", base_path: ""),
          )
        end
      end

      context "with partial credentials (only secret key)" do
        let(:secret_access_key) { "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" }

        it do
          expect(check).to have_a_problem.with_priority("low").with_message(
            I18n.t("dashboard.problem.s3_credentials_partial", base_path: ""),
          )
        end
      end

      context "with GlobalSetting credentials" do
        let(:global_access_key_id) { "AKIAIOSFODNN7EXAMPLE" }
        let(:global_secret_access_key) { "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" }

        it { expect(check).to be_chill_about_it }
      end

      context "with partial GlobalSetting credentials" do
        let(:global_access_key_id) { "AKIAIOSFODNN7EXAMPLE" }

        it do
          expect(check).to have_a_problem.with_priority("low").with_message(
            I18n.t("dashboard.problem.s3_credentials_partial", base_path: ""),
          )
        end
      end
    end

    context "when S3 uploads are locally enabled with bucket" do
      let(:locally_enabled) { true }
      let(:bucket_name) { "my-upload-bucket" }

      context "with explicit credentials" do
        let(:access_key_id) { "AKIAIOSFODNN7EXAMPLE" }
        let(:secret_access_key) { "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" }

        it { expect(check).to be_chill_about_it }
      end

      context "without explicit credentials" do
        it do
          expect(check).to have_a_problem.with_priority("low").with_message(
            I18n.t("dashboard.problem.s3_credentials", base_path: ""),
          )
        end
      end
    end
  end
end
