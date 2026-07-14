# frozen_string_literal: true

module DiscoursePostEvent
  class EventsController < DiscoursePostEventController
    requires_login except: %i[index show]
    skip_before_action :check_xhr, only: [:index], if: :ics_request?

    def index
      search_params = filtered_events_params.to_h

      if ics_request?
        search_params["after"] ||= 3.months.ago.iso8601
        search_params["order"] ||= "asc"
      end

      @events =
        DiscoursePostEvent::EventFinder.search(current_user, search_params).includes(
          :event_dates,
          :image_upload,
          post: {
            topic: %i[tags category],
          },
        )

      respond_to do |format|
        format.ics do
          @calendar_name = calendar_name_for_ics

          after_time = filtered_events_params[:after]&.to_datetime || Time.current
          before_time = filtered_events_params[:before]&.to_datetime || 1.year.from_now

          @ics_events =
            @events.flat_map do |event|
              if event.recurring?
                expanded =
                  DiscoursePostEvent::Action::ExpandOccurrences.call(
                    event: event,
                    after: after_time,
                    before: before_time,
                    limit: 52,
                    current_occurrence_only: current_occurrence_only_event_ids.include?(event.id),
                  )
                expanded[:occurrences].map { |occ| { event: event, **occ } }
              else
                [{ event: event, starts_at: event.starts_at, ends_at: event.ends_at }]
              end
            end

          @ics_events = @ics_events.sort_by { |e| e[:starts_at] || Time.current }.first(500)

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
                  current_occurrence_only: current_occurrence_only_event_ids.include?(event.id),
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
      Invite.call(service_params.deep_merge(params: { event_id: params[:id] })) do
        on_success { render json: success_json }
        on_model_not_found(:event) { raise Discourse::NotFound }
        on_failed_policy(:can_act_on_event) { raise Discourse::InvalidAccess }
        on_failed_contract { raise Discourse::InvalidParameters }
      end
    end

    def show
      event = Event.includes(:image_upload).find(params[:id])
      guardian.ensure_can_see!(event.post)

      serializer = EventSerializer.new(event, scope: guardian)
      render_json_dump(serializer)
    end

    def destroy
      DestroyEvent.call(service_params.deep_merge(params: { event_id: params[:id] })) do
        on_success { render json: success_json }
        on_model_not_found(:event) { raise Discourse::NotFound }
        on_failed_policy(:can_act_on_event) { raise Discourse::InvalidAccess }
        on_failed_contract { raise Discourse::InvalidParameters }
      end
    end

    def csv_bulk_invite
      file = params[:file] || (params[:files] || []).first

      # Render (don't raise) every outcome: exceptions raised inside `hijack`
      # surface as a 500 instead of the intended status.
      hijack do
        CsvBulkInvite.call(
          service_params.deep_merge(params: { event_id: params[:id], file: file }),
        ) do
          on_success { render json: success_json }
          on_model_not_found(:event) { render json: failed_json, status: :not_found }
          on_failed_policy(:can_edit_post) { render json: failed_json, status: :forbidden }
          on_failed_policy(:can_create_event) { render json: failed_json, status: :forbidden }
          on_failed_policy(:file_present) do
            render json: failed_json.merge(error_type: "invalid_parameters"), status: :bad_request
          end
          on_model_not_found(:invitees) { render_bulk_invite_error }
          on_failed_contract { render_bulk_invite_error }
          on_exceptions { render_bulk_invite_error }
          on_failure { render_bulk_invite_error }
        end
      end
    end

    def bulk_invite
      BulkInvite.call(service_params.deep_merge(params: { event_id: params[:id] })) do
        on_success { render json: success_json }
        on_model_not_found(:event) { raise Discourse::NotFound }
        on_failed_policy(:can_edit_post) { raise Discourse::InvalidAccess }
        on_failed_policy(:can_create_event) { raise Discourse::InvalidAccess }
        on_failed_policy(:invitees_present) { raise Discourse::InvalidParameters.new(:invitees) }
        on_failed_contract { raise Discourse::InvalidParameters }
        on_exceptions { render_bulk_invite_error }
        on_failure { render_bulk_invite_error }
      end
    end

    private

    def render_bulk_invite_error
      render json:
               failed_json.merge(errors: [I18n.t("discourse_post_event.errors.bulk_invite.error")]),
             status: :unprocessable_entity
    end

    def ics_request?
      request.format.symbol == :ics
    end

    def filtered_events_params
      params.permit(
        :post_id,
        :category_id,
        :include_subcategories,
        :include_interested,
        :include_ongoing,
        :limit,
        :attending_user,
        :before,
        :after,
        :order,
      )
    end

    def current_occurrence_only_event_ids
      @current_occurrence_only_event_ids ||= single_occurrence_rsvp_event_ids
    end

    def single_occurrence_rsvp_event_ids
      attending_username = filtered_events_params[:attending_user]
      return Set.new if attending_username.blank?

      attending_user = User.find_by(username_lower: attending_username.downcase)
      return Set.new if attending_user.blank?

      DiscoursePostEvent::Invitee
        .unscoped
        .with_status(:going)
        .where(post_id: @events.map(&:id), user_id: attending_user.id, recurring: false)
        .pluck(:post_id)
        .to_set
    end

    def format_time(event, time)
      return nil unless time
      return time.utc.strftime("%Y-%m-%d") if event.all_day

      if event.show_local_time
        time.in_time_zone(event.timezone).strftime("%Y-%m-%dT%H:%M:%S")
      else
        time.in_time_zone(event.timezone).iso8601(3)
      end
    end

    def calendar_name_for_ics
      translation_key =
        if filtered_events_params[:attending_user].present? &&
             current_user&.username_lower == filtered_events_params[:attending_user].downcase
          "my_events_feed_name"
        else
          "all_events_feed_name"
        end

      I18n.t(
        "discourse_calendar.calendar_subscriptions.#{translation_key}",
        site_title: SiteSetting.title,
      )
    end
  end
end
