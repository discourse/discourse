# frozen_string_literal: true

RSpec.describe CspScriptSrcValidator do
  describe "#valid_value?" do
    let(:validator) { described_class.new }

    it "returns true for empty string" do
      expect(validator.valid_value?("")).to eq true
    end

    it "returns true for single valid value" do
      expect(validator.valid_value?("'unsafe-eval'")).to eq true
    end

    it "returns true for multiple valid values" do
      values = %w[
        'unsafe-eval'
        'wasm-unsafe-eval'
        'sha384-oqVuAfXRKap7fdgcCY5-ykM6+R9GqQ8K/uxy9rx_HNQlGYl1kPzQho1wx4JwY8wC'
      ].join("|")
      expect(validator.valid_value?(values)).to eq true
    end

    it "returns false on invalid values" do
      %w[
        unsafe-eval
        'unsafe-eval'!
        !'unsafe-eval'
        'sha256-not+a+valid+base64===='
        'md5-not+a+supported+hash+algo'
        'sha224-not+a+supported+hash+algo'
      ].each { |invalid_value| expect(validator.valid_value?(invalid_value)).to eq false }
    end

    it "returns false on input including at least 1 invalid value" do
      expect(validator.valid_value?("'unsafe-eval'|'md5-not+a+supported+hash+algo'")).to eq false
    end
  end
end
