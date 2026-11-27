import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { extractError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const TYPE_ICONS = {
  text: "hashtag",
  voice: "volume-high",
  forum: "fab-discourse",
};

export default class CreateChannelModal extends Component {
  @service router;
  @service toasts;

  @tracked flash;
  @tracked submitting = false;
  formApi;

  formData = {
    type: this.creator.types[0],
    section:
      this.sidebarSections.sections[this.args.model.sectionIndex]?.name ?? null,
    name: "",
    isPrivate: false,
    groupIds: [],
  };

  // A name typed into the picker isn't a section yet, and select-kit only
  // shows a selection that's among its options.
  sectionOptions = (value) => {
    const names = this.sidebarSections.names;
    return value && !names.includes(value) ? [...names, value] : names;
  };

  get creator() {
    return this.args.model.creator;
  }

  get sidebarSections() {
    return this.args.model.sidebarSections;
  }

  // Only admins can save sections, but they can make one from here by typing
  // a new name.
  get showSectionField() {
    return this.sidebarSections.canEdit;
  }

  get types() {
    return this.creator.types.map((type) => ({
      type,
      icon: TYPE_ICONS[type],
      title: i18n(themePrefix(`create_channel.types.${type}.title`)),
      description: i18n(
        themePrefix(`create_channel.types.${type}.description`)
      ),
    }));
  }

  @action
  validate(data, { addError }) {
    if (data.isPrivate && !data.groupIds?.length) {
      addError("groupIds", {
        title: i18n(themePrefix("create_channel.groups")),
        message: i18n(themePrefix("create_channel.groups_required")),
      });
    }
  }

  @action
  async create(data) {
    this.flash = null;

    try {
      const { key, route, models, notice } = await this.creator.create(data);
      const notices = notice ? [notice] : [];

      // The channel exists by now, so a failure here leaves it at the top of
      // the list rather than failing the whole thing.
      if (this.showSectionField && data.section) {
        try {
          await this.sidebarSections.addChannel(data.section, key);
        } catch (error) {
          notices.push(extractError(error));
        }
      }

      this.args.closeModal();

      notices.forEach((message) => this.toasts.warning({ data: { message } }));

      this.router.transitionTo(route, ...models);
    } catch (error) {
      this.flash = extractError(error);
    }
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  // The buttons sit in the modal's fixed footer, outside the form.
  @action
  async submit() {
    this.submitting = true;
    try {
      await this.formApi.submit();
    } finally {
      this.submitting = false;
    }
  }

  <template>
    <DModal
      class="concord-create-channel-modal"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @title={{i18n (themePrefix "create_channel.title")}}
    >
      <:body>
        <Form
          @data={{this.formData}}
          @onRegisterApi={{this.registerApi}}
          @onSubmit={{this.create}}
          @validate={{this.validate}}
          as |form data|
        >
          <form.Field
            @format="full"
            @name="type"
            @title={{i18n (themePrefix "create_channel.type")}}
            @type="radio-group"
            @validation="required"
            as |field|
          >
            <field.Control as |radioGroup|>
              {{#each this.types as |option|}}
                <radioGroup.Radio @value={{option.type}} as |radio|>
                  <radio.Title>
                    {{dIcon option.icon}}
                    {{option.title}}
                  </radio.Title>
                  <radio.Description>{{option.description}}</radio.Description>
                </radioGroup.Radio>
              {{/each}}
            </field.Control>
          </form.Field>

          {{#if this.showSectionField}}
            <form.Field
              @description={{i18n
                (themePrefix "create_channel.section_description")
              }}
              @format="full"
              @name="section"
              @title={{i18n (themePrefix "create_channel.section")}}
              @type="custom"
              as |field|
            >
              <field.Control>
                <ComboBox
                  @content={{this.sectionOptions field.value}}
                  @nameProperty={{null}}
                  @onChange={{field.set}}
                  @options={{hash
                    allowAny=true
                    filterable=true
                    none=(themePrefix "create_channel.no_section")
                  }}
                  @value={{field.value}}
                  @valueProperty={{null}}
                />
              </field.Control>
            </form.Field>
          {{/if}}

          <form.Field
            @format="full"
            @name="name"
            @title={{i18n (themePrefix "create_channel.name")}}
            @type="input"
            @validation="required|length:1,50"
            as |field|
          >
            <field.Control
              placeholder={{i18n
                (themePrefix "create_channel.name_placeholder")
              }}
            />
          </form.Field>

          <form.Field
            @description={{i18n
              (themePrefix "create_channel.private_description")
            }}
            @format="full"
            @name="isPrivate"
            @title={{i18n (themePrefix "create_channel.private")}}
            @type="toggle"
            as |field|
          >
            <field.Control />
          </form.Field>

          {{#if data.isPrivate}}
            <form.Field
              @description={{if
                (eq data.type "voice")
                (i18n (themePrefix "create_channel.voice_groups_note"))
              }}
              @format="full"
              @name="groupIds"
              @title={{i18n (themePrefix "create_channel.groups")}}
              @type="custom"
              as |field|
            >
              <field.Control>
                <GroupChooser
                  @content={{this.creator.groups}}
                  @labelProperty="name"
                  @onChange={{field.set}}
                  @value={{field.value}}
                />
              </field.Control>
            </form.Field>
          {{/if}}
        </Form>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.submit}}
          @isLoading={{this.submitting}}
          @label={{themePrefix "create_channel.submit"}}
        />
        <DButton
          class="btn-transparent"
          @action={{@closeModal}}
          @label="cancel"
        />
      </:footer>
    </DModal>
  </template>
}
