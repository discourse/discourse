import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import TextField from "discourse/components/text-field";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const States = {
  initializing: "initializing",
  checking: "checking",
  valid: "valid",
  invalid: "invalid",
  saving: "saving",
  new: "new",
  existing: "existing",
  unpublishing: "unpublishing",
  unpublished: "unpublished",
};

export default class PublishPageModal extends Component {
  @service store;

  @tracked state = States.initializing;
  @tracked reason = null;
  @tracked publishedPage = null;

  constructor() {
    super(...arguments);
    this.store
      .find("published_page", this.args.model.id)
      .then((page) => {
        this.state = States.existing;
        this.publishedPage = page;
      })
      .catch(this.startNew);
  }

  get initializing() {
    return this.state === States.initializing;
  }

  get checking() {
    return this.state === States.checking;
  }

  get valid() {
    return this.state === States.valid;
  }

  get invalid() {
    return this.state === States.invalid;
  }

  get saving() {
    return this.state === States.saving;
  }

  get new() {
    return this.state === States.new;
  }

  get existing() {
    return this.state === States.existing;
  }

  get unpublishing() {
    return this.state === States.unpublishing;
  }

  get unpublished() {
    return this.state === States.unpublished;
  }

  get disabled() {
    return this.state !== States.valid;
  }

  get showUrl() {
    return (
      this.state === States.valid ||
      this.state === States.saving ||
      this.state === States.existing
    );
  }

  get showUnpublish() {
    return this.state === States.existing || this.state === States.unpublishing;
  }

  @action
  startCheckSlug() {
    if (this.state === States.existing) {
      return;
    }

    this.state = States.checking;
  }

  @action
  checkSlug() {
    if (this.state === States.existing) {
      return;
    }
    return ajax("/pub/check-slug", {
      data: { slug: this.publishedPage.slug },
    }).then((result) => {
      if (result.valid_slug) {
        this.state = States.valid;
      } else {
        this.state = States.invalid;
        this.reason = result.reason;
      }
    });
  }

  @action
  unpublish() {
    this.state = States.unpublishing;
    return this.publishedPage
      .destroyRecord()
      .then(() => {
        this.state = States.unpublished;
        this.args.model.set("publishedPage", null);
      })
      .catch((result) => {
        this.state = States.existing;
        popupAjaxError(result);
      });
  }

  @action
  publish() {
    this.state = States.saving;

    return this.publishedPage
      .update(this.publishedPage.getProperties("slug", "public"))
      .then(() => {
        this.state = States.existing;
        this.args.model.set("publishedPage", this.publishedPage);
      })
      .catch((errResult) => {
        popupAjaxError(errResult);
        this.state = States.existing;
      });
  }

  @action
  startNew() {
    this.state = States.new;
    this.publishedPage = this.store.createRecord(
      "published_page",
      this.args.model.getProperties("id", "slug", "public")
    );
    this.checkSlug();
  }

  @action
  onChangePublic(event) {
    this.publishedPage.set("public", event.target.checked);

    if (this.showUnpublish) {
      this.publish();
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "topic.publish_page.title"}}
      class="publish-page-modal"
    >
      <:body>
        {{#if this.unpublished}}
          <p>{{i18n "topic.publish_page.unpublished"}}</p>
        {{else}}
          <ConditionalLoadingSpinner @condition={{this.initializing}}>
            <p class="publish-description">{{i18n
                "topic.publish_page.description"
              }}</p>

            <form>
              <div class="controls">
                <label>{{i18n "topic.publish_page.slug"}}</label>
                <TextField
                  @value={{this.publishedPage.slug}}
                  @onChange={{this.checkSlug}}
                  @onChangeImmediate={{this.startCheckSlug}}
                  @disabled={{this.existing}}
                  class="publish-slug"
                />
              </div>

              <div class="controls">
                <label>{{i18n "topic.publish_page.public"}}</label>

                <p class="description">
                  <Input
                    @type="checkbox"
                    @checked={{readonly this.publishedPage.public}}
                    {{on "click" this.onChangePublic}}
                  />
                  {{i18n "topic.publish_page.public_description"}}
                </p>
              </div>
            </form>

            <div class="publish-url">
              <ConditionalLoadingSpinner @condition={{this.checking}} />

              {{#if this.existing}}
                <div class="current-url">
                  {{i18n "topic.publish_page.publish_url"}}
                  <div>
                    <a
                      href={{this.publishedPage.url}}
                      target="_blank"
                      rel="noopener noreferrer"
                    >{{this.publishedPage.url}}</a>
                  </div>
                </div>
              {{else}}
                {{#if this.showUrl}}
                  <div class="valid-slug">
                    {{i18n "topic.publish_page.preview_url"}}
                    <div class="example-url">{{this.publishedPage.url}}</div>
                  </div>
                {{/if}}

                {{#if this.invalid}}
                  {{i18n "topic.publish_page.invalid_slug"}}
                  <span class="invalid-slug">{{this.reason}}.</span>
                {{/if}}
              {{/if}}

            </div>
          </ConditionalLoadingSpinner>
        {{/if}}
      </:body>
      <:footer>
        {{#if this.showUnpublish}}
          <DButton
            @label="topic.publish_page.unpublish"
            @icon="trash-can"
            @isLoading={{this.unpublishing}}
            @action={{this.unpublish}}
            class="btn-danger"
          />

          <DButton
            @icon="xmark"
            @label="close"
            @action={{@closeModal}}
            class="close-publish-page"
          />
        {{else if this.unpublished}}
          <DButton
            @label="topic.publish_page.publishing_settings"
            @action={{this.startNew}}
          />
        {{else}}
          <DButton
            @label="topic.publish_page.publish"
            @icon="file"
            @disabled={{this.disabled}}
            @isLoading={{this.saving}}
            @action={{this.publish}}
            class="btn-primary publish-page"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
