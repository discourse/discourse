class Jobs::Onceoff < Jobs::Base
  sidekiq_options retry: false

  def self.name_for(klass)
    klass.name.sub(/^Jobs\:\:/, '')
  end

  # Pass `force: true` to force it happen again
  def execute(args)
    job_name = self.class.name_for(self.class)

    if args[:force] || !OnceoffLog.where(job_name: job_name).exists?
      return if $redis.exists(self.class.name)
      DistributedMutex.synchronize(self.class.name) do
        execute_onceoff(args)
        OnceoffLog.create(job_name: job_name)
      end
    end
  end

  def self.enqueue_all
    previously_ran = OnceoffLog.pluck(:job_name).uniq

    ObjectSpace.each_object(Class).select { |klass| klass < self }.each do |klass|
      job_name = name_for(klass)
      unless previously_ran.include?(job_name)
        Jobs.enqueue(job_name.underscore.to_sym)
      end
    end
  end

end
