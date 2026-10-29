# frozen_string_literal: true

RSpec.describe CspScriptSrcValidator do
  describe "#valid_value?" do
    context "when values are valid" do
      context "when value is an empty string" do
        it { is_expected.to be_a_valid_value "" }
      end

      context "when there's a single value" do
        shared_examples "csp script src validator for valid_value" do |valid_value|
          it { is_expected.to be_a_valid_value valid_value }
        end

        include_examples "csp script src validator for valid_value", "'unsafe-eval'"
        include_examples "csp script src validator for valid_value", "'wasm-unsafe-eval'"
        include_examples "csp script src validator for valid_value", "'sha256-valid_h4sH'"
        include_examples "csp script src validator for valid_value", "'sha384-valid-h4sH='"
        include_examples "csp script src validator for valid_value", "'sha512-valid+h4sH=='"
      end

      context "when there are multiple valid values" do
        let(:valid_values) do
          %w[
            'unsafe-eval'
            'wasm-unsafe-eval'
            'sha384-oqVuAfXRKap7fdgcCY5-ykM6+R9GqQ8K/uxy9rx_HNQlGYl1kPzQho1wx4JwY8wC'
          ].join("|")
        end

        it { is_expected.to be_a_valid_value valid_values }
      end
    end

    context "when values are invalid" do
      context "when there's a single value" do
        shared_examples "csp script src validator for invalid_value" do |invalid_value|
          it { is_expected.not_to be_a_valid_value invalid_value }
        end

        include_examples "csp script src validator for invalid_value", "unsafe-eval"
        include_examples "csp script src validator for invalid_value", "'unsafe-eval'!"
        include_examples "csp script src validator for invalid_value", "!'unsafe-eval'"
        include_examples "csp script src validator for invalid_value",
                         "'sha256-not+a+valid+base64===='"
        include_examples "csp script src validator for invalid_value",
                         "'md5-not+a+supported+hash+algo'"
        include_examples "csp script src validator for invalid_value",
                         "'sha224-not+a+supported+hash+algo'"
      end

      context "when there is at least 1 invalid value and 1 valid value" do
        it { is_expected.not_to be_a_valid_value "'unsafe-eval'|'md5-not+a+supported+hash+algo'" }
      end
    end
  end
end
