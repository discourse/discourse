# frozen_string_literal: true

DiscoursePostEvent::Engine.routes.draw do
  get "/discourse-post-event/events" => "events#index", :format => :json
  get "/discourse-post-event/events/:id" => "events#show"
  delete "/discourse-post-event/events/:id" => "events#destroy"
  post "/discourse-post-event/events" => "events#create"
  post "/discourse-post-event/events/:id/csv-bulk-invite" => "events#csv_bulk_invite"
  post "/discourse-post-event/events/:id/bulk-invite" => "events#bulk_invite", :format => :json
  post "/discourse-post-event/events/:id/invite" => "events#invite"
  put "/discourse-post-event/events/:event_id/invitees/:invitee_id" => "invitees#update"
  post "/discourse-post-event/events/:event_id/invitees" => "invitees#create"
  get "/discourse-post-event/events/:post_id/invitees" => "invitees#index"
  delete "/discourse-post-event/events/:post_id/invitees/:id" => "invitees#destroy"
  get "/upcoming-events" => "upcoming_events#index"
  get "/upcoming-events/mine" => "upcoming_events#index"
end

Discourse::Application.routes.draw do
  mount ::DiscourseCalendar::Engine, at: "/"
  mount ::DiscoursePostEvent::Engine, at: "/"

  scope constraints: StaffConstraint.new do
    get "/admin/plugins/calendar" => "admin/plugins#index"
    get "/admin/discourse-calendar/holiday-regions/:region_code/holidays" =>
          "admin/discourse_calendar/admin_holidays#index"
    post "/admin/discourse-calendar/holidays/disable" =>
           "admin/discourse_calendar/admin_holidays#disable"
    delete "/admin/discourse-calendar/holidays/enable" =>
             "admin/discourse_calendar/admin_holidays#enable"
  end
end
