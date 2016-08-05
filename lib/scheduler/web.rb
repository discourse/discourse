# Based off sidetiq https://github.com/tobiassvn/sidetiq/blob/master/lib/sidetiq/web.rb
module Scheduler
  module Web
    VIEWS = File.expand_path('views', File.dirname(__FILE__)) unless defined? VIEWS

    def self.registered(app)

      app.helpers do
        def sane_time(time)
          return unless time
          time
        end

        def sane_duration(duration)
          return unless duration
          if duration < 1000
            "#{duration}ms"
          elsif duration < 60*1000
            "#{'%.2f' % (duration/1000.0)} secs"
          end
        end
      end

      app.get "/scheduler" do
        RailsMultisite::ConnectionManagement.with_connection("default") do
          @manager = Scheduler::Manager.without_runner
          @schedules = Scheduler::Manager.discover_schedules.sort do |a,b|
            a_next = a.schedule_info.next_run
            b_next = b.schedule_info.next_run
            if a_next && b_next
              a_next <=> b_next
            elsif a_next
              -1
            else
              1
            end
          end
          erb File.read(File.join(VIEWS, 'scheduler.erb')), locals: {view_path: VIEWS}
        end
      end

      app.get "/scheduler/history" do
        @scheduler_stats = SchedulerStat.order('started_at desc').limit(200)
        erb File.read(File.join(VIEWS, 'history.erb')), locals: {view_path: VIEWS}
      end

      app.post "/scheduler/:name/trigger" do
        halt 404 unless (name = params[:name])

        RailsMultisite::ConnectionManagement.with_connection("default") do
          klass = name.constantize
          info = klass.schedule_info
          info.next_run = Time.now.to_f
          info.write!

          redirect "#{root_path}scheduler"
        end
      end

    end
  end
end

Sidekiq::Web.register(Scheduler::Web)
Sidekiq::Web.tabs["Scheduler"] = "scheduler"
