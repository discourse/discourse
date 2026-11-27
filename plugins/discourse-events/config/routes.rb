# frozen_string_literal: true

# URL paths keep their original `discourse-post-event` / `discourse-calendar`
# spellings: they are a public API surface, unlike the Ruby namespaces.
DiscourseEvents::Engine.routes.draw do
  get "/discourse-post-event/registration-forms/new" => "registration_forms#new", :format => false
  get "/discourse-post-event/registration-forms/mine" => "registration_forms#mine"
  get "/discourse-post-event/registration-forms/:id/edit" => "registration_forms#edit", :id => /\d+/
  resources :registration_forms,
            path: "/discourse-post-event/registration-forms",
            only: %i[index show create update destroy],
            defaults: {
              format: :json,
            }

  get "/discourse-post-event/events" => "events#index",
      :constraints => {
        format: /(json|ics)/,
      },
      :defaults => {
        format: :json,
      }
  get "/discourse-post-event/events/:id" => "events#show"
  delete "/discourse-post-event/events/:id" => "events#destroy"
  post "/discourse-post-event/events/:id/csv-bulk-invite" => "events#csv_bulk_invite"
  post "/discourse-post-event/events/:id/bulk-invite" => "events#bulk_invite", :format => :json
  post "/discourse-post-event/events/:id/invite" => "events#invite"
  put "/discourse-post-event/events/:event_id/invitees/:invitee_id" => "invitees#update"
  post "/discourse-post-event/events/:event_id/invitees" => "invitees#create"
  get "/discourse-post-event/events/:post_id/invitees" => "invitees#index"
  delete "/discourse-post-event/events/:post_id/invitees/:id" => "invitees#destroy"
  get "/upcoming-events/:view/:year/:month/:day" => "upcoming_events#index"
  get "/upcoming-events" => "upcoming_events#index"
  get "/upcoming-events/mine/:view/:year/:month/:day" => "upcoming_events#index"
  get "/upcoming-events/mine" => "upcoming_events#index"
  get "/discourse-calendar/livestream/zoom/signature" => "livestream#prepare_zoom_signature",
      :format => :json
  get "/discourse-calendar/livestream/zoom/frame" => "livestream#zoom_frame"
  post "/discourse-calendar/livestream/notification-pause" => "livestream#pause_notifications",
       :format => :json
  delete "/discourse-calendar/livestream/notification-pause/:pause_key" =>
           "livestream#resume_notifications",
         :format => :json
end

Discourse::Application.routes.draw do
  mount DiscourseEvents::Engine, at: "/"

  get "t/:slug/:topic_id/zoom" => "topics#show", :constraints => { topic_id: /\d+/ }

  scope constraints: AdminConstraint.new do
    get "/admin/plugins/discourse-events/submissions" => "admin/discourse_events/submissions#index"
    get "/admin/plugins/discourse-events/registration-forms" => "admin/plugins#index"
    get "/admin/plugins/discourse-events/registration-forms/new" => "admin/plugins#index"
    get "/admin/plugins/discourse-events/registration-forms/:id/edit" => "admin/plugins#index",
        :id => /\d+/
  end

  scope constraints: StaffConstraint.new do
    get "/admin/plugins/calendar" => "admin/plugins#index"
    get "/admin/plugins/discourse-events" => "admin/plugins#index"
    get "/admin/plugins/discourse-events/holidays" => "admin/plugins#index"
    get "/admin/discourse-calendar/holiday-regions/:region_code/holidays" =>
          "admin/discourse_events/holidays#index"
    post "/admin/discourse-calendar/holidays/disable" => "admin/discourse_events/holidays#disable"
    delete "/admin/discourse-calendar/holidays/enable" => "admin/discourse_events/holidays#enable"
  end
end
