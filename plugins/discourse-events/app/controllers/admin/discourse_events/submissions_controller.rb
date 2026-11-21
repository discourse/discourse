# frozen_string_literal: true

module Admin::DiscourseEvents
  class SubmissionsController < Admin::AdminController
    requires_plugin ::DiscourseEvents::PLUGIN_NAME

    PAGE_SIZE = 50

    def index
      return render body: nil unless request.format.json?

      page = fetch_int_from_params(:page, default: 1, min: 1)
      scope =
        ::DiscourseEvents::Events::Event.visible.joins(post: :topic).left_joins(:registrations)
      scope =
        if params[:form_id] == ::DiscourseEvents::Events::RegistrationForm::ACCOUNT_ONLY
          scope.with_account_only_registration
        elsif (form_id = fetch_int_from_params(:form_id, default: nil, min: 1))
          form =
            ::DiscourseEvents::Events::RegistrationForm
              .with_deleted
              .select(:id, :deleted_at, "definition->>'title' AS title")
              .find(form_id)
          scope.with_library_form.where(registration_form_id: form_id)
        else
          scope.where(
            "discourse_post_event_events.registration_form IS NOT NULL OR discourse_event_registrations.id IS NOT NULL",
          )
        end
      search = params[:search].to_s.strip
      scope = search_by_name(scope, search) if search.present?
      events =
        scope
          .group("discourse_post_event_events.id")
          .select(
            "discourse_post_event_events.id, discourse_post_event_events.name, discourse_post_event_events.registration_topic_id",
            "discourse_post_event_events.registration_form->>'title' AS form_title",
            "COUNT(discourse_event_registrations.id) AS submission_count, MAX(discourse_event_registrations.created_at) AS latest_submission_at",
          )
          .order(
            Arel.sql("latest_submission_at DESC NULLS LAST, discourse_post_event_events.id DESC"),
          )
          .preload(:event_hosts, post: :topic)
          .limit(PAGE_SIZE + 1)
          .offset((page - 1) * PAGE_SIZE)
          .to_a
      page_events = events.first(PAGE_SIZE)
      hosts_by_id =
        User
          .where(id: page_events.flat_map(&:registration_host_ids).uniq)
          .select(:id, :username, :uploaded_avatar_id)
          .to_h do |host|
            [host.id, { username: host.username, avatar_template: host.avatar_template }]
          end
      render json: {
               events: page_events.map { |event| summary(event, hosts_by_id) },
               unused_form:
                 if form && !form.trashed? && page == 1 && search.empty? && events.empty?
                   { id: form.id, title: form.title }
                 end,
               previous_page: page > 1 ? page - 1 : nil,
               next_page: events.size > PAGE_SIZE ? page + 1 : nil,
             }
    end

    private

    def search_by_name(scope, search)
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(search)}%"
      forms =
        ::DiscourseEvents::Events::RegistrationForm.with_deleted.where(
          "definition->>'title' ILIKE ?",
          pattern,
        )
      scope.where(<<~SQL, pattern:, form_ids: forms.select(:id))
        COALESCE(NULLIF(BTRIM(discourse_post_event_events.name), ''), topics.title) ILIKE :pattern
        OR discourse_post_event_events.registration_form->>'title' ILIKE :pattern
        OR discourse_post_event_events.registration_form_id IN (:form_ids)
      SQL
    end

    def summary(event, hosts_by_id)
      topic = event.post.topic
      can_export = guardian.can_export_event_registrations?(event)
      hosts = hosts_by_id.values_at(*event.registration_host_ids).compact
      {
        id: event.id,
        title: event.name.presence || topic.title,
        url: topic.relative_url(event.post.post_number),
        hosts:,
        host_usernames: hosts.pluck(:username),
        form_title: event.form_title,
        submission_count: event.submission_count,
        latest_submission_at: event.latest_submission_at,
        can_export: can_export,
        report_topic_id: can_export ? event.registration_topic_id : nil,
      }
    end
  end
end
