module Jobs

  class CleanUpDigestKeys < Jobs::Scheduled
    every 1.day

    def execute(args)
      # Remove unused digest keys
      DigestUnsubscribeKey.where('created_at < ?', 2.months.ago).delete_all
    end
  end

end

