import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class VoiceRoomForm extends Component {
  @service site;
  @service siteSettings;
  @service chatApi;

  @tracked isSaving = false;
  @tracked chatChannels = [];

  get isAdminContext() {
    return !this.args.onSubmit;
  }

  get formData() {
    return {
      name: this.args.room?.name || "",
      slug: this.args.room?.slug || "",
      description: this.args.room?.description || "",
      public: this.args.room?.public ?? false,
      room_type: this.args.room?.room_type || "open",
      max_participants: this.args.room?.max_participants || null,
      video_enabled: this.args.room?.video_enabled ?? true,
      livekit_enabled: this.args.room?.livekit_enabled ?? false,
      chat_channel_id: this.args.room?.chat_channel_id || null,
      chat_idle_minutes: this.args.room?.chat_idle_minutes ?? 15,
      max_quality_profile:
        this.args.room?.max_quality_profile || "site_default",
    };
  }

  get showVideoToggle() {
    return this.siteSettings.voice_video_enabled;
  }

  get showLivekitToggle() {
    return this.site.voice_livekit_per_room_available;
  }

  get showChatSettings() {
    return (
      this.siteSettings.chat_enabled && this.siteSettings.voice_chat_enabled
    );
  }

  get maxParticipantsValidation() {
    return "integer|number:2,200";
  }

  get roomTypeOptions() {
    return [
      {
        id: "open",
        name: i18n("voice.room.type_open"),
        description: i18n("voice.room.type_open_description"),
      },
      {
        id: "stage",
        name: i18n("voice.room.type_stage"),
        description: i18n("voice.room.type_stage_description"),
      },
    ];
  }

  get qualityProfileOptions() {
    return ["site_default", "standard", "high", "maximum"].map((profile) => ({
      id: profile,
      name:
        profile === "site_default"
          ? i18n("voice.admin.room.quality_site_default")
          : i18n(`voice.quality.${profile}`),
    }));
  }

  get submitLabel() {
    if (this.isAdminContext) {
      return this.args.room?.id ? "voice.admin.update" : "voice.admin.create";
    }
    return "voice.room.save";
  }

  @action
  async loadChatChannels() {
    if (!this.showChatSettings) {
      return;
    }
    try {
      const collection = this.chatApi.channels();
      await collection.load();
      this.chatChannels = (collection.items ?? []).filter(
        (channel) => channel.threadingEnabled
      );
    } catch (e) {
      popupAjaxError(e);
    }
  }

  isStageType(roomType) {
    return roomType === "stage";
  }

  @action
  async handleSubmit(data) {
    this.isSaving = true;

    try {
      if (this.args.onSubmit) {
        await this.args.onSubmit(data);
      } else {
        const room = this.args.room;
        room.setProperties(data);
        await room.save();
        this.args.onSave?.(room);
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    <div class="voice-room-form {{if this.isAdminContext 'admin-detail'}}">
      {{#if this.isAdminContext}}
        <BackButton
          @label="voice.admin.back"
          @route="adminPlugins.show.voice-rooms.index"
          class="voice-admin-back"
        />
      {{/if}}

      <Form
        @data={{this.formData}}
        @onSubmit={{this.handleSubmit}}
        class="voice-room-form__form"
        as |form data|
      >
        <form.Field
          @type="input"
          @name="name"
          @title={{i18n "voice.admin.room.name"}}
          @format="full"
          @validation="required|length:1,80"
          @placeholder={{i18n "voice.admin.room.name_placeholder"}}
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @type="input"
          @name="slug"
          @title={{i18n "voice.admin.room.slug"}}
          @description={{i18n "voice.admin.room.slug_help"}}
          @format="full"
          @placeholder={{i18n "voice.admin.room.slug_placeholder"}}
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @type="textarea"
          @name="description"
          @title={{i18n "voice.admin.room.description"}}
          @format="full"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @type="radio-group"
          @name="room_type"
          @title={{i18n "voice.admin.room.room_type"}}
          @format="full"
          as |field|
        >
          <field.Control as |radioGroup|>
            {{#each this.roomTypeOptions as |option|}}
              <radioGroup.Radio @value={{option.id}}>
                <strong>{{option.name}}</strong>
                —
                {{option.description}}
              </radioGroup.Radio>
            {{/each}}
          </field.Control>
        </form.Field>

        {{#if (this.isStageType data.room_type)}}
          <div class="voice-room-form__stage-hint">
            {{i18n "voice.room.type_stage_hint"}}
          </div>
        {{/if}}

        <form.Field
          @type="toggle"
          @name="public"
          @title={{i18n "voice.admin.room.public"}}
          @description={{i18n "voice.admin.room.public_help"}}
          @format="full"
          as |field|
        >
          <field.Control />
          {{#if @onManageMembers}}
            <DButton
              @action={{@onManageMembers}}
              @icon="users"
              @label="voice.admin.room.manage_members"
              class="btn-link voice-room-form__manage-members
                {{if data.public '--hidden'}}"
            />
          {{/if}}
        </form.Field>

        {{#if this.showVideoToggle}}
          <form.Field
            @type="toggle"
            @name="video_enabled"
            @title={{i18n "voice.admin.room.video_enabled"}}
            @description={{if
              (this.isStageType data.room_type)
              (i18n "voice.admin.room.video_enabled_stage_help")
              (i18n "voice.admin.room.video_enabled_help")
            }}
            @format="full"
            as |field|
          >
            <field.Control />
          </form.Field>
        {{/if}}

        {{#if this.showLivekitToggle}}
          <form.Field
            @type="toggle"
            @name="livekit_enabled"
            @title={{i18n "voice.admin.room.livekit_enabled"}}
            @description={{i18n "voice.admin.room.livekit_enabled_help"}}
            @format="full"
            as |field|
          >
            <field.Control />
          </form.Field>
        {{/if}}

        <form.Field
          @type="input-number"
          @name="max_participants"
          @title={{i18n "voice.admin.room.max_participants"}}
          @description={{i18n "voice.admin.room.max_participants_help"}}
          @validation={{this.maxParticipantsValidation}}
          as |field|
        >
          <field.Control />
        </form.Field>

        <details class="voice-room-form__quality">
          <summary>{{i18n "voice.admin.room.quality_section"}}</summary>

          <form.Field
            @type="select"
            @name="max_quality_profile"
            @title={{i18n "voice.admin.room.max_quality_profile"}}
            @description={{i18n "voice.admin.room.max_quality_profile_help"}}
            @format="full"
            as |field|
          >
            <field.Control @includeNone={{false}} as |select|>
              {{#each this.qualityProfileOptions as |option|}}
                <select.Option @value={{option.id}}>
                  {{option.name}}
                </select.Option>
              {{/each}}
            </field.Control>
          </form.Field>
        </details>

        {{#if this.showChatSettings}}
          <div
            class="voice-room-form__chat"
            {{didInsert this.loadChatChannels}}
          >
            <form.Field
              @type="select"
              @name="chat_channel_id"
              @title={{i18n "voice.admin.room.chat_channel"}}
              @description={{i18n "voice.admin.room.chat_channel_help"}}
              @format="full"
              as |field|
            >
              <field.Control as |select|>
                {{#each this.chatChannels as |channel|}}
                  <select.Option
                    @value={{channel.id}}
                  >{{channel.title}}</select.Option>
                {{/each}}
              </field.Control>
            </form.Field>

            {{#unless this.chatChannels.length}}
              <div class="voice-room-form__chat-empty">
                {{i18n "voice.admin.room.chat_channel_none"}}
              </div>
            {{/unless}}

            {{#if data.chat_channel_id}}
              <form.Field
                @type="input-number"
                @name="chat_idle_minutes"
                @title={{i18n "voice.admin.room.chat_idle_minutes"}}
                @description={{i18n "voice.admin.room.chat_idle_minutes_help"}}
                @validation="integer|number:2,1440"
                as |field|
              >
                <field.Control />
              </form.Field>

              <div class="voice-room-form__chat-preview">
                {{i18n "voice.admin.room.chat_thread_hint"}}
              </div>
            {{/if}}
          </div>
        {{/if}}

        <form.Submit
          @label={{this.submitLabel}}
          @disabled={{this.isSaving}}
          class="voice-room-form__submit"
        />
      </Form>
    </div>
  </template>
}
