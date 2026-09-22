# frozen_string_literal: true

module DiscourseWorkflows
  class Credential::Connect
    include Service::Base

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    params do
      attribute :credential_id, :integer
      validates :credential_id, presence: true
    end

    model :credential
    policy :oauth_credential
    try Oauth2Provider::Error do
      step :connect
    end

    private

    def fetch_credential(params:)
      DiscourseWorkflows::Credential.find_by(id: params.credential_id)
    end

    def oauth_credential(credential:)
      credential.oauth2?
    end

    def connect(credential:)
      Oauth2Connection.new(credential).connect
    end
  end
end
