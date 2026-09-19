# frozen_string_literal: true

RSpec.describe Email::Sns do
  describe ".allowed_topic_arn?" do
    let(:topic_arn) { "arn:aws:sns:us-east-1:123456789012:discourse-bounces" }
    let(:other_topic_arn) { "arn:aws:sns:us-east-1:999999999999:attacker-topic" }

    before { SiteSetting.aws_sns_topic_arn_allowlist = topic_arn }

    it "returns false for a blank topic arn" do
      expect(described_class.allowed_topic_arn?(nil)).to eq(false)
      expect(described_class.allowed_topic_arn?("")).to eq(false)
    end

    it "returns false for a topic arn that is not on the allowlist" do
      expect(described_class.allowed_topic_arn?(other_topic_arn)).to eq(false)
    end

    it "returns true for a topic arn on the allowlist" do
      expect(described_class.allowed_topic_arn?(topic_arn)).to eq(true)
    end

    it "matches any entry of a pipe-separated allowlist" do
      SiteSetting.aws_sns_topic_arn_allowlist = "#{topic_arn}|#{other_topic_arn}"

      expect(described_class.allowed_topic_arn?(topic_arn)).to eq(true)
      expect(described_class.allowed_topic_arn?(other_topic_arn)).to eq(true)
    end

    it "returns false when the allowlist is empty" do
      SiteSetting.aws_sns_topic_arn_allowlist = ""

      expect(described_class.allowed_topic_arn?(topic_arn)).to eq(false)
    end
  end

  describe ".authentic?" do
    it "delegates to the AWS SNS message verifier" do
      require "aws-sdk-sns"
      raw = "{}"
      Aws::SNS::MessageVerifier.any_instance.expects(:authentic?).with(raw).returns(true)

      expect(described_class.authentic?(raw)).to eq(true)
    end
  end
end
