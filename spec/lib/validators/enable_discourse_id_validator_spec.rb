# frozen_string_literal: true

RSpec.describe EnableDiscourseIdValidator do
  subject(:validator) { described_class.new }

  describe "#valid_value?" do
    describe "when credentials are configured" do
      before do
        SiteSetting.discourse_id_client_id = "foo"
        SiteSetting.discourse_id_client_secret = "bar"
      end

      describe "when value is false" do
        it "should be valid" do
          expect(validator.valid_value?("f")).to eq(true)
        end
      end

      describe "when value is true" do
        it "should be valid" do
          expect(validator.valid_value?("t")).to eq(true)
        end
      end
    end

    describe "when discourse_id_client_id is not set" do
      before { SiteSetting.discourse_id_client_id = "" }

      describe "when value is false" do
        it "should be valid" do
          expect(validator.valid_value?("f")).to eq(true)
        end
      end

      describe "when value is true" do
        it "should automatically register" do
          allow(DiscourseId::Register).to receive(:call).and_return(
            instance_double(Service::Base::Context, success?: true),
          )
          expect(validator.valid_value?("t")).to eq(true)
        end

        it "should show an appropriate error message when something went wrong" do
          failed_context = Service::Base::Context.new
          failed_context.fail(error: "an error")
          allow(DiscourseId::Register).to receive(:call).and_return(failed_context)

          expect(validator.valid_value?("t")).to eq(false)
          expect(validator.error_message).to eq("an error")
        end

        it "shows a default error message when something went _very_ wrong" do
          failed_context = Service::Base::Context.new
          failed_context.fail
          allow(DiscourseId::Register).to receive(:call).and_return(failed_context)

          expect(validator.valid_value?("t")).to eq(false)
          expect(validator.error_message).to eq(
            I18n.t("site_settings.errors.discourse_id_credentials"),
          )
        end
      end
    end

    describe "when discourse_id_client_secret is not set" do
      before { SiteSetting.discourse_id_client_secret = "" }

      describe "when value is false" do
        it "should be valid" do
          expect(validator.valid_value?("f")).to eq(true)
        end
      end

      describe "when value is true" do
        it "automatically registers" do
          allow(DiscourseId::Register).to receive(:call).and_return(
            instance_double(Service::Base::Context, success?: true),
          )

          expect(validator.valid_value?("t")).to eq(true)
        end

        it "shows an appropriate error message when something went wrong" do
          failed_context = Service::Base::Context.new
          failed_context.fail(error: "another error")
          allow(DiscourseId::Register).to receive(:call).and_return(failed_context)

          expect(validator.valid_value?("t")).to eq(false)
          expect(validator.error_message).to eq("another error")
        end

        it "shows a default error message when something went _very_ wrong" do
          failed_context = Service::Base::Context.new
          failed_context.fail(error: nil)
          allow(DiscourseId::Register).to receive(:call).and_return(failed_context)

          expect(validator.valid_value?("t")).to eq(false)
          expect(validator.error_message).to eq(
            I18n.t("site_settings.errors.discourse_id_credentials"),
          )
        end
      end
    end
  end
end
