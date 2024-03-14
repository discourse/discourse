# frozen_string_literal: true

task "hijacks" => "environment" do
  Rails.application.eager_load!

  hijacks = Hijack.hijacks

  Rails.application.routes.routes.each do |route|
    path = route.path.spec.to_s
    controller = route.requirements[:controller]
    action = route.requirements[:action]

    if path && controller && action
      action = action.to_sym
      begin
        controller = "#{controller}_controller".classify.constantize
      rescue StandardError
      end

      puts path if hijacks.include?([controller, action])
    end
  end
end
