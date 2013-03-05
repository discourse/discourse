module Jobs

  class Base
    include Sidekiq::Worker

    def self.delayed_perform(opts={})
      self.new.perform(opts)
    end

    def self.mutex
      @mutex ||= Mutex.new
    end

    def execute(opts={})
      raise "Overwrite me!"
    end

    def perform(opts={})
      opts = opts.with_indifferent_access

      if opts.delete(:sync_exec)
        if opts.has_key?(:current_site_id) && opts[:current_site_id] != RailsMultisite::ConnectionManagement.current_db
          raise ArgumentError.new("You can't connect to another database when executing a job synchronously.")
        else
          return execute(opts)
        end
      end


      dbs =
        if opts[:current_site_id]
          [opts[:current_site_id]]
        else
          RailsMultisite::ConnectionManagement.all_dbs
        end

      dbs.each do |db|
        begin
          Jobs::Base.mutex.synchronize do
            RailsMultisite::ConnectionManagement.establish_connection(:db => db)
            execute(opts)
          end
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      end
    end
  end

  def self.enqueue(job_name, opts={})

    klass_name = "Jobs::#{job_name.to_s.camelcase}"
    klass = klass_name.constantize

    # Unless we want to work on all sites
    unless opts.delete(:all_sites)
      opts[:current_site_id] ||= RailsMultisite::ConnectionManagement.current_db
    end

    # If we are able to queue a job, do it
    if SiteSetting.queue_jobs?
      if opts[:delay_for].present?
        klass.delay_for(opts.delete(:delay_for)).delayed_perform(opts)
      else
        Sidekiq::Client.enqueue(klass_name.constantize, opts)
      end
    else
      # Otherwise execute the job right away
      opts.delete(:delay_for)
      opts[:sync_exec] = true
      klass.new.perform(opts)
    end

  end

  def self.enqueue_in(secs, job_name, opts={})
    enqueue(job_name, opts.merge!(delay_for: secs))
  end

end

# Require all jobs
Dir["#{Rails.root}/lib/jobs/*"].each {|file| require_dependency file }
