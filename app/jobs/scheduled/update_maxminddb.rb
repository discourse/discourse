require_dependency 'discourse_ip_info'

module Jobs
  class UpdateMaxMindDb < Jobs::Scheduled
    every 7.days

    def execute(args)
      DiscourseIpInfo.update!
      DiscourseIpInfo.reload
    end
  end
end
