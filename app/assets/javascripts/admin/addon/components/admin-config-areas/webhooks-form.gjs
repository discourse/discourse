import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import BackButton from "discourse/components/back-button";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import Form from "discourse/components/form";
import GroupSelector from "discourse/components/group-selector";
import PluginOutlet from "discourse/components/plugin-outlet";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import WebhookEventChooser from "admin/components/webhook-event-chooser";
import CategorySelector from "select-kit/components/category-selector";
import TagChooser from "select-kit/components/tag-chooser";

export default class AdminConfigAreasWebhookForm extends Component {
  @service router;
  @service siteSettings;
  @service store;

  @tracked webhook = this.args.webhook;

  @tracked loadingExtras = true;

  @tracked webhookEventTypes = [];
  @tracked defaultEventTypes = {};
  @tracked groupedEventTypes = {};
  @tracked contentTypes = [];
  @tracked deliveryStatuses = [];

  constructor() {
    super(...arguments);

    this.#loadExtras();
  }

  @cached
  get formData() {
    return {
      payload_url: this.webhook.payload_url,
      content_type: this.webhook.content_type,
      secret: this.webhook.secret === "" ? null : this.webhook.secret,
      categories: this.webhook.categories,
      group_names: this.webhook.group_names,
      tag_names: this.webhook.tag_names,
      wildcard: this.webhook.wildcard,
      web_hook_event_types: this.webhook.web_hook_event_types,
      verify_certificate: this.webhook.verify_certificate,
      active: this.webhook.active,
    };
  }

  async #loadExtras() {
    try {
      this.loadingExtras = true;

      const webhooks = await this.store.findAll("web-hook");

      this.groupedEventTypes = webhooks.extras.grouped_event_types;
      this.defaultEventTypes = webhooks.extras.default_event_types;
      this.contentTypes = webhooks.extras.content_types;
      this.deliveryStatuses = webhooks.extras.delivery_statuses;

      if (this.webhook.isNew) {
        this.webhookEventTypes = [...this.defaultEventTypes];
      } else {
        this.webhookEventTypes = [...this.webhook.web_hook_event_types];
      }
    } finally {
      this.loadingExtras = false;
    }
  }

  get showTagsFilter() {
    return this.siteSettings.tagging_enabled;
  }

  get saveButtonLabel() {
    return this.webhook.isNew
      ? "admin.web_hooks.create"
      : "admin.web_hooks.save";
  }

  @action
  async save(data) {
    try {
      const isNew = this.webhook.isNew;

      this.webhook.setProperties({
        ...data,
        web_hook_event_types: this.webhookEventTypes,
      });

      await this.webhook.save();

      if (isNew) {
        this.router.transitionTo("adminWebHooks.show", this.webhook);
      } else {
        this.router.transitionTo("adminWebHooks.index");
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <BackButton @route="adminWebHooks.index" @label="admin.web_hooks.back" />

    <div class="admin-config-area user-field">
      <div class="admin-config-area__primary-content">
        <div class="admin-config-area-card">
          <div class="web-hook-container">
            <ConditionalLoadingSection @isLoading={{this.loadingExtras}}>
              <p>{{i18n "admin.web_hooks.detailed_instruction"}}</p>
              <Form
                @onSubmit={{this.save}}
                @data={{this.formData}}
                as |form transientData|
              >
                <form.Field
                  @name="payload_url"
                  @title={{i18n "admin.web_hooks.payload_url"}}
                  @format="large"
                  @validation="required|url"
                  as |field|
                >
                  <field.Input
                    placeholder={{i18n
                      "admin.web_hooks.payload_url_placeholder"
                    }}
                  />
                </form.Field>

                <form.Field
                  @name="content_type"
                  @title={{i18n "admin.web_hooks.content_type"}}
                  @format="large"
                  @validation="required"
                  as |field|
                >
                  <field.Select as |select|>
                    {{#each this.contentTypes as |contentType|}}
                      <select.Option
                        @value={{contentType.id}}
                      >{{contentType.name}}</select.Option>
                    {{/each}}
                  </field.Select>
                </form.Field>

                <form.Field
                  @name="secret"
                  @title={{i18n "admin.web_hooks.secret"}}
                  @description={{i18n "admin.web_hooks.secret_placeholder"}}
                  @format="large"
                  @validation="length:12"
                  as |field|
                >
                  <field.Input />
                </form.Field>

                <form.Field
                  @name="wildcard"
                  @title={{i18n "admin.web_hooks.event_chooser"}}
                  @validation="required"
                  @onSet={{this.setRequirement}}
                  @format="full"
                  as |field|
                >
                  <field.RadioGroup as |radioGroup|>
                    <radioGroup.Radio @value="individual">
                      {{i18n "admin.web_hooks.individual_event"}}
                    </radioGroup.Radio>
                    {{#if (eq transientData.wildcard "individual")}}
                      <div class="event-selector">
                        {{#each-in
                          this.groupedEventTypes
                          as |group eventTypes|
                        }}
                          <div class="event-group">
                            {{i18n
                              (concat
                                "admin.web_hooks." group "_event.group_name"
                              )
                            }}
                            {{#each eventTypes as |type|}}
                              <WebhookEventChooser
                                @type={{type}}
                                @group={{group}}
                                @eventTypes={{this.webhookEventTypes}}
                              />
                            {{/each}}
                          </div>
                        {{/each-in}}
                      </div>
                    {{/if}}
                    <radioGroup.Radio @value="wildcard">
                      {{i18n "admin.web_hooks.wildcard_event"}}
                    </radioGroup.Radio>
                  </field.RadioGroup>
                </form.Field>

                <form.Field
                  @name="categories"
                  @title={{i18n "admin.web_hooks.categories_filter"}}
                  @description={{i18n
                    "admin.web_hooks.categories_filter_instructions"
                  }}
                  @format="large"
                  as |field|
                >
                  <field.Custom>
                    <CategorySelector
                      @categories={{field.value}}
                      @onChange={{field.set}}
                    />
                  </field.Custom>
                </form.Field>

                {{#if this.showTagsFilter}}
                  <form.Field
                    @name="tag_names"
                    @title={{i18n "admin.web_hooks.tags_filter"}}
                    @description={{i18n
                      "admin.web_hooks.tags_filter_instructions"
                    }}
                    @format="large"
                    as |field|
                  >
                    <field.Custom>
                      <TagChooser
                        @tags={{field.value}}
                        @everyTag={{true}}
                        @excludeSynonyms={{true}}
                        @onChange={{field.set}}
                      />
                    </field.Custom>
                  </form.Field>
                {{/if}}

                <form.Field
                  @name="group_names"
                  @title={{i18n "admin.web_hooks.groups_filter"}}
                  @description={{i18n
                    "admin.web_hooks.groups_filter_instructions"
                  }}
                  @format="large"
                  as |field|
                >
                  <field.Custom>
                    <GroupSelector
                      @groupNames={{field.value}}
                      @groupFinder={{this.webhook.groupFinder}}
                      @onChange={{field.set}}
                    />
                  </field.Custom>
                </form.Field>

                <span>
                  <PluginOutlet
                    @name="web-hook-fields"
                    @connectorTagName="div"
                    @outletArgs={{hash model=this.webhook}}
                  />
                </span>

                <form.Field
                  @name="verify_certificate"
                  @title={{i18n "admin.web_hooks.verify_certificate"}}
                  @showTitle={{false}}
                  as |field|
                >
                  <field.Checkbox />
                </form.Field>

                <form.Field
                  @name="active"
                  @title={{i18n "admin.web_hooks.active"}}
                  @showTitle={{false}}
                  as |field|
                >
                  <field.Checkbox />
                </form.Field>

                <form.Actions>
                  <form.Submit class="save" @label={{this.saveButtonLabel}} />
                  <form.Button
                    @route="adminWebHooks.index"
                    @label="admin.web_hooks.cancel"
                    class="btn-default"
                  />
                </form.Actions>
              </Form>
            </ConditionalLoadingSection>
          </div>
        </div>
      </div>
    </div>
  </template>
}
