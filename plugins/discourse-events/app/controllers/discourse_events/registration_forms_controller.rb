# frozen_string_literal: true

module DiscourseEvents
  class RegistrationFormsController < ::ApplicationController
    requires_plugin DiscourseEvents::PLUGIN_NAME
    requires_login
    skip_before_action :check_xhr, only: %i[new mine edit], unless: -> { request.format.json? }
    before_action :ensure_can_create_form, only: %i[index show new mine create]
    before_action :find_manageable_form, only: %i[edit update destroy]

    def index
      scope = Events::RegistrationForm.all
      if params[:for_reports] == "true"
        ensure_admin
        all_forms = Events::RegistrationForm.with_deleted
        attached_ids = Events::Event.visible.with_library_form.select(:registration_form_id)
        scope = all_forms.where(deleted_at: nil).or(all_forms.where(id: attached_ids))
      end
      render_list(scope)
    end

    def mine
      return render "default/empty" unless request.format.json?
      render_list(Events::RegistrationForm.where(created_by_id: current_user.id), mine: true)
    end

    def show
      form = Events::RegistrationForm.with_deleted.find(params[:id])
      if form.trashed? && !Events::Event.with_library_form.exists?(registration_form_id: form.id)
        raise Discourse::NotFound
      end
      render_form(form)
    end

    def new
      render "default/empty"
    end

    def edit
      return render "default/empty" unless request.format.json?
      in_use = @form.in_use?
      render json: {
               id: @form.id,
               definition: @form.definition,
               in_use:,
               has_linked_events:
                 in_use ||
                   Events::Event
                     .visible
                     .with_library_form
                     .joins(post: :topic)
                     .exists?(registration_form_id: @form.id),
             }
    end

    def create
      form =
        Events::RegistrationForm.create!(definition: definition_params, created_by: current_user)
      render_form(form, :created)
    end

    def update
      @form.update!(definition: definition_params)
      render_form(@form)
    end

    def destroy
      @form.trash!(current_user)
      head :no_content
    end

    private

    def find_manageable_form
      @form = Events::RegistrationForm.find(params[:id])
      guardian.ensure_can_manage_event_registration_form!(@form)
    end

    def render_list(scope, mine: false)
      columns = [:id, Arel.sql("definition->>'title'"), Arel.sql("definition->>'description'")]
      include_usage = params[:include_usage] == "true"
      if mine || include_usage
        scope = scope.left_joins(:created_by)
        columns.push(User.arel_table[:username], User.arel_table[:uploaded_avatar_id])
      end
      if include_usage
        ensure_admin
        columns << Arel.sql("jsonb_array_length(definition->'fields')")
        counts =
          Events::Event
            .visible
            .joins(post: :topic)
            .with_library_form
            .group(:registration_form_id)
            .count
      end
      forms = scope.order(Arel.sql("lower(definition->>'title')"), :id).pluck(*columns)
      in_use_ids = Events::RegistrationForm.in_use_ids(forms.map(&:first)) if mine || counts
      summaries =
        forms.map do |id, title, description, username, avatar_id, field_count|
          summary = { id:, title:, description: }
          if username
            summary[:created_by] = {
              username:,
              avatar_template: User.avatar_template(username, avatar_id),
            }
          end
          summary[:in_use] = in_use_ids.include?(id) if in_use_ids
          summary.merge!(field_count:, event_count: counts.fetch(id, 0)) if counts
          summary
        end
      if counts && !mine
        summaries.unshift(
          id: Events::RegistrationForm::ACCOUNT_ONLY,
          builtin: true,
          title: I18n.t("js.event_registration.account_only"),
          description: I18n.t("js.event_registration.library.account_only_description"),
          field_count: 0,
          event_count:
            Events::Event.visible.joins(post: :topic).with_account_only_registration.count,
        )
      end
      render json: { registration_forms: summaries }
    end

    def ensure_can_create_form
      guardian.ensure_can_create_event_registration_form!
    end

    def definition_params
      params
        .require(:definition)
        .permit(
          :title,
          :description,
          fields: [
            :id,
            :type,
            :label,
            :content,
            :required,
            :description,
            :placeholder,
            { choices: %i[id label] },
          ],
        )
        .to_h
    end

    def render_form(form, status = :ok)
      render json: { id: form.id, definition: form.definition }, status:
    end
  end
end
