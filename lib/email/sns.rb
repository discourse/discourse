# frozen_string_literal: true

module Email
  class Sns
    class << self
      def authentic?(raw)
        require "aws-sdk-sns"
        Aws::SNS::MessageVerifier.new.authentic?(raw)
      end

      def allowed_topic_arn?(topic_arn)
        return false if topic_arn.blank?
        SiteSetting.aws_sns_topic_arn_allowlist.to_s.split("|").include?(topic_arn)
      end
    end
  end
end
