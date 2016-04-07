# base.rb uses this style of require, so maintain usage of it here
require_dependency "#{Rails.root}/app/jobs/regular/user_email.rb"

module Jobs
  class ForgotPassword < UserEmail

    sidekiq_options queue: 'critical'

    def execute(args)
      args[:type] = :forgot_password
      super(args)
    end
  end
end
