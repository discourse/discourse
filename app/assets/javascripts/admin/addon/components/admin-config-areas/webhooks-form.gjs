import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import icon from "discourse/helpers/d-icon";
import CategorySelector from "select-kit/components/category-selector";
import ComboBox from "select-kit/components/combo-box";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import DButton from "discourse/components/d-button";
import GroupSelector from "discourse/components/group-selector";
import { LinkTo } from "@ember/routing";
import { Input } from "@ember/component";
import { i18n } from "discourse-i18n";
import InputTip from "discourse/components/input-tip";
import PluginOutlet from "discourse/components/plugin-outlet";
import RadioButton from "discourse/components/radio-button";
import TagChooser from "select-kit/components/tag-chooser";
import TextField from "discourse/components/text-field";
import WebhookEventChooser from "admin/components/webhook-event-chooser";
import { popupAjaxError } from "discourse/lib/ajax-error";

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

  async #loadExtras() {
    try {
      this.loadingExtras = true;

      const webhooks = await this.store.findAll("web-hook");

      this.groupedEventTypes = webhooks.extras.grouped_event_types;
      this.defaultEventTypes = webhooks.extras.default_event_types;
      this.contentTypes = webhooks.extras.content_types;
      this.deliveryStatuses = webhooks.extras.delivery_statuses;

      this.webhook.set("web_hook_event_types", this.defaultEventTypes);
    } finally {
      this.loadingExtras = false;
    }
  }

  get showTagsFilter() {
    return this.siteSettings.tagging_enabled;
  }

  get saveButtonText() {
    return this.webhook.isNew ? i18n("admin.web_hooks.create") : i18n("admin.web_hooks.save");
  }

  eventTypeValidation() {
    if (!this.webhook.wildcard_web_hook && this.webhook.web_hook_event_types?.length < 1) {
      return EmberObject.create({
        failed: true,
        reason: i18n("admin.web_hooks.event_type_missing"),
      });
    }
  }

  @action
  async save() {
    const isNew = this.webhook.isNew;

    this.saved = false;

    try {
      await this.webhook.save();

      this.saved = true;

      if(isNew) {
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
            <p>{{i18n "admin.web_hooks.detailed_instruction"}}</p>

            <form class="web-hook form-horizontal">
              <div class="control-group">
                <label for="payload-url">{{i18n "admin.web_hooks.payload_url"}}</label>
                <TextField
                  @name="payload-url"
                  @value={{this.webhook.payload_url}}
                  @placeholderKey="admin.web_hooks.payload_url_placeholder"
                />
                <InputTip @validation={{this.urlValidation}} />
              </div>

              <div class="control-group">
                <label for="content-type">{{i18n "admin.web_hooks.content_type"}}</label>
                <ComboBox
                  @content={{this.contentTypes}}
                  @name="content-type"
                  @value={{this.webhook.content_type}}
                  @onChange={{fn (mut this.webhook.content_type)}}
                />
              </div>

              <div class="control-group">
                <label for="secret">{{i18n "admin.web_hooks.secret"}}</label>
                <TextField
                  @name="secret"
                  @value={{this.webhook.secret}}
                  @placeholderKey="admin.web_hooks.secret_placeholder"
                />
                <InputTip @validation={{this.secretValidation}} />
              </div>

              <div class="control-group">
                <label>{{i18n "admin.web_hooks.event_chooser"}}</label>

                <label class="subscription-choice">
                  <RadioButton
                    @name="subscription-choice"
                    @onChange={{fn (mut this.webhook.wildcard_web_hook) false}}
                    @value={{false}}
                    @selection={{this.webhook.wildcard_web_hook}}
                  />
                  {{i18n "admin.web_hooks.individual_event"}}
                  <InputTip @validation={{this.eventTypeValidation}} />
                </label>

                <ConditionalLoadingSection @isLoading={{this.loadingExtras}}>
                  {{#unless this.webhook.wildcard_web_hook}}
                    <div class="event-selector">
                      {{#each-in this.groupedEventTypes as |group eventTypes|}}
                        <div class="event-group">
                          {{i18n (concat "admin.web_hooks." group "_event.group_name")}}
                          {{#each eventTypes as |type|}}
                            <WebhookEventChooser
                              @type={{type}}
                              @group={{group}}
                              @eventTypes={{this.webhook.web_hook_event_types}}
                            />
                          {{/each}}
                        </div>
                      {{/each-in}}
                    </div>
                  {{/unless}}
                </ConditionalLoadingSection>

                <label class="subscription-choice">
                  <RadioButton
                    @name="subscription-choice"
                    @onChange={{fn (mut this.webhook.wildcard_web_hook) true}}
                    @value={{true}}
                    @selection={{this.webhook.wildcard_web_hook}}
                  />
                  {{i18n "admin.web_hooks.wildcard_event"}}
                </label>
              </div>

              <div class="filters control-group">
                <div class="filter">
                  <label>{{icon "circle" class="tracking"}}{{i18n
                      "admin.web_hooks.categories_filter"
                    }}</label>
                  <CategorySelector
                    @categories={{this.webhook.categories}}
                    @onChange={{fn (mut this.webhook.categories)}}
                  />
                  <div class="instructions">{{i18n
                      "admin.web_hooks.categories_filter_instructions"
                    }}</div>
                </div>

                {{#if this.showTagsFilter}}
                  <div class="filter">
                    <label>{{icon "circle" class="tracking"}}{{i18n
                        "admin.web_hooks.tags_filter"
                      }}</label>
                    <TagChooser
                      @tags={{this.webhook.tag_names}}
                      @everyTag={{true}}
                      @excludeSynonyms={{true}}
                    />
                    <div class="instructions">{{i18n
                        "admin.web_hooks.tags_filter_instructions"
                      }}</div>
                  </div>
                {{/if}}

                <div class="filter">
                  <label>{{icon "circle" class="tracking"}}{{i18n
                      "admin.web_hooks.groups_filter"
                    }}</label>
                  <GroupSelector
                    @groupNames={{this.webhook.groupsFilterInName}}
                    @groupFinder={{this.webhook.groupFinder}}
                  />
                  <div class="instructions">{{i18n
                      "admin.web_hooks.groups_filter_instructions"
                    }}</div>
                </div>
              </div>

              <span>
                <PluginOutlet
                  @name="web-hook-fields"
                  @connectorTagName="div"
                  @outletArgs={{hash model=this.webhook}}
                />
              </span>

              <label>
                <Input
                  @type="checkbox"
                  name="verify_certificate"
                  @checked={{this.webhook.verify_certificate}}
                />
                {{i18n "admin.web_hooks.verify_certificate"}}
              </label>

              <div>
                <label class="checkbox-label">
                  <Input @type="checkbox" name="active" @checked={{this.webhook.active}} />
                  {{i18n "admin.web_hooks.active"}}
                </label>

                {{#if this.webhook.active}}
                  <div class="instructions">{{i18n "admin.web_hooks.active_notice"}}</div>
                {{/if}}
              </div>
            </form>

            <div class="controls">
              <DButton
                @translatedLabel={{this.saveButtonText}}
                @action={{this.save}}
                class="btn-primary admin-webhooks__save-button"
              />

              {{#if this.webhook.isNew}}
                <LinkTo @route="adminWebHooks" class="btn btn-default">
                  {{i18n "admin.web_hooks.cancel"}}
                </LinkTo>
              {{else}}
                <LinkTo
                  @route="adminWebHooks.show"
                  @model={{this.webhook}}
                  class="btn btn-default"
                >
                  {{i18n "admin.web_hooks.cancel"}}
                </LinkTo>
              {{/if}}
            </div>
          </div>
        </div>
      </div>
    </div>
  </template>
}
