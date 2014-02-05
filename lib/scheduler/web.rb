# Based off sidetiq https://github.com/tobiassvn/sidetiq/blob/master/lib/sidetiq/web.rb
module Scheduler
  module Web
    VIEWS = File.expand_path('views', File.dirname(__FILE__))

    def self.registered(app)
      app.get "/scheduler" do
        @schedules = Scheduler::Manager.discover_schedules
        @manager = Scheduler::Manager.without_runner
        erb File.read(File.join(VIEWS, 'scheduler.erb')), locals: {view_path: VIEWS}
      end

      app.post "/scheduler/:name/trigger" do
        halt 404 unless (name = params[:name])

        klass = name.constantize
        info = klass.schedule_info
        info.next_run = Time.now.to_f
        info.write!

        redirect "#{root_path}scheduler"
      end

    end
  end
end

Sidekiq::Web.register(Scheduler::Web)
Sidekiq::Web.tabs["Scheduler"] = "scheduler"
