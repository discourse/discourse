# frozen_string_literal: true

module DiscoursePostEvent
  class EventsController < DiscoursePostEventController
    skip_before_action :check_xhr, only: [:index], if: :ics_request?

    def index
      @events =
        DiscoursePostEvent::EventFinder.search(current_user, filtered_events_params).includes(
          :event_dates,
          post: {
            topic: %i[tags category],
          },
        )

      respond_to do |format|
        format.ics do
          filename = "events-#{Digest::SHA1.hexdigest(@events.map(&:id).sort.join("-"))}.ics"
          response.headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""
        end

        format.json do
          # The detailed serializer is currently not used anywhere in the frontend, but available via API
          serializer = params[:include_details] == "true" ? EventSerializer : BasicEventSerializer

          serialized_events =
            @events.map do |event|
              expanded =
                DiscoursePostEvent::Action::ExpandOccurrences.call(
                  event: event,
                  after: filtered_events_params[:after]&.to_datetime || Time.current,
                  before: filtered_events_params[:before]&.to_datetime,
                  limit: filtered_events_params[:limit]&.to_i || 50,
                )

              formatted_occurrences =
                expanded[:occurrences].map do |occurrence|
                  {
                    starts_at: format_time(event, occurrence[:starts_at]),
                    ends_at: format_time(event, occurrence[:ends_at]),
                  }
                end

              serializer.new(
                event,
                scope: guardian,
                root: false,
                occurrences: formatted_occurrences,
                include_occurrences: true,
              ).as_json
            end

          render json: { events: serialized_events }
        end
      end
    end

    def invite
      event = Event.find(params[:id])
      guardian.ensure_can_act_on_discourse_post_event!(event)
      invites = Array(params.permit(invites: [])[:invites])
      users = User.real.where(username: invites)

      users.each { |user| event.create_notification!(user, event.post) }

      render json: success_json
    end

    def show
      event = Event.find(params[:id])
      guardian.ensure_can_see!(event.post)

      serializer = EventSerializer.new(event, scope: guardian)
      render_json_dump(serializer)
    end

    def destroy
      event = Event.find(params[:id])
      guardian.ensure_can_act_on_discourse_post_event!(event)
      event.publish_update!
      event.destroy
      render json: success_json
    end

    def csv_bulk_invite
      require "csv"

      event = Event.find(params[:id])
      guardian.ensure_can_edit!(event.post)
      guardian.ensure_can_create_discourse_post_event!

      file = params[:file] || (params[:files] || []).first
      raise Discourse::InvalidParameters.new(:file) if file.blank?

      hijack do
        begin
          invitees = []

          CSV.foreach(file.tempfile) do |row|
            invitees << { identifier: row[0], attendance: row[1] || "going" } if row[0].present?
          end

          if invitees.present?
            Jobs.enqueue(
              :discourse_post_event_bulk_invite,
              event_id: event.id,
              invitees: invitees,
              current_user_id: current_user.id,
            )
            render json: success_json
          else
            render json:
                     failed_json.merge(
                       errors: [I18n.t("discourse_post_event.errors.bulk_invite.error")],
                     ),
                   status: :unprocessable_entity
          end
        rescue StandardError
          render json:
                   failed_json.merge(
                     errors: [I18n.t("discourse_post_event.errors.bulk_invite.error")],
                   ),
                 status: :unprocessable_entity
        end
      end
    end

    def bulk_invite
      event = Event.find(params[:id])
      guardian.ensure_can_edit!(event.post)
      guardian.ensure_can_create_discourse_post_event!

      invitees = Array(params[:invitees]).reject { |x| x.empty? }
      raise Discourse::InvalidParameters.new(:invitees) if invitees.blank?

      begin
        Jobs.enqueue(
          :discourse_post_event_bulk_invite,
          event_id: event.id,
          invitees: invitees.as_json,
          current_user_id: current_user.id,
        )
        render json: success_json
      rescue StandardError
        render json:
                 failed_json.merge(
                   errors: [I18n.t("discourse_post_event.errors.bulk_invite.error")],
                 ),
               status: :unprocessable_entity
      end
    end

    private

    def ics_request?
      request.format.symbol == :ics
    end

    def filtered_events_params
      params.permit(
        :post_id,
        :category_id,
        :include_subcategories,
        :limit,
        :attending_user,
        :before,
        :after,
        :order,
      )
    end

    def format_time(event, time)
      return nil unless time

      if event.show_local_time
        time.in_time_zone(event.timezone).strftime("%Y-%m-%dT%H:%M:%S")
      else
        time.in_time_zone(event.timezone).iso8601(3)
      end
    end
  end
end
