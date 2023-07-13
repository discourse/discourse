# frozen_string_literal: true
require "swagger_helper"

RSpec.describe "notifications" do
  let(:admin) { Fabricate(:admin) }
  let!(:notification) { Fabricate(:notification, user: admin) }

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  path "/notifications.json" do
    get "Get the notifications that belong to the current user" do
      tags "Notifications"
      operationId "getNotifications"

      produces "application/json"
      response "200", "notifications" do
        schema type: :object,
               properties: {
                 notifications: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: {
                         type: :integer,
                       },
                       user_id: {
                         type: :integer,
                       },
                       notification_type: {
                         type: :integer,
                       },
                       read: {
                         type: :boolean,
                       },
                       created_at: {
                         type: :string,
                       },
                       post_number: {
                         type: %i[string null],
                       },
                       topic_id: {
                         type: %i[integer null],
                       },
                       slug: {
                         type: %i[string null],
                       },
                       data: {
                         type: :object,
                         properties: {
                           badge_id: {
                             type: :integer,
                           },
                           badge_name: {
                             type: :string,
                           },
                           badge_slug: {
                             type: :string,
                           },
                           badge_title: {
                             type: :boolean,
                           },
                           username: {
                             type: :string,
                           },
                         },
                       },
                     },
                   },
                 },
                 total_rows_notifications: {
                   type: :integer,
                 },
                 seen_notification_id: {
                   type: :integer,
                 },
                 load_more_notifications: {
                   type: :string,
                 },
               }

        run_test!
      end
    end
  end

  path "/notifications/mark-read.json" do
    put "Mark notifications as read" do
      tags "Notifications"
      operationId "markNotificationsAsRead"
      consumes "application/json"
      parameter name: :notification,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    id: {
                      type: :integer,
                      description: "(optional) Leave off to mark all notifications as read",
                    },
                  },
                }

      produces "application/json"
      response "200", "notifications marked read" do
        schema type: :object, properties: { success: { type: :string } }

        run_test!
      end
    end
  end
end
