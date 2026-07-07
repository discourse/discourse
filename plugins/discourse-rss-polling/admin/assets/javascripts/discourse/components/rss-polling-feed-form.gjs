import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import Form from "discourse/components/form";
import DButtonTooltip from "discourse/float-kit/components/d-button-tooltip";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isHttpUrl } from "discourse/lib/url";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import UserChooser from "discourse/select-kit/components/user-chooser";
import { not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import { i18n } from "discourse-i18n";
import RssPollingFeedItemList from "discourse/plugins/discourse-rss-polling/discourse/components/rss-polling-feed-item-list";
import {
  errorMessage,
  FeedEnabledToggle,
  previewSummary,
} from "discourse/plugins/discourse-rss-polling/discourse/lib/rss-polling-item";
import RssPollingFeedSettings from "../../admin/models/rss-polling-feed-settings";

export default class RssPollingFeedForm extends Component {
  @service dialog;
  @service router;
  @service toasts;

  @tracked polling = false;
  @tracked submitting = false;
  @tracked dirty = false;
  @tracked testing = false;
  @tracked testResults = null;
  @tracked testTotal = 0;
  @tracked testError = null;
  @tracked categoryRequirements = [];
  #requirementsLoaded = Promise.resolve();

  constructor() {
    super(...arguments);
    this.feedToggle = new FeedEnabledToggle(this.args.feed, this.toasts);
    this.loadCategoryRequirements(this.args.feed?.discourse_category_id);
  }

  get isEditing() {
    return !!this.args.feed;
  }

  @cached
  get requiredTagNames() {
    return [
      ...new Set(this.categoryRequirements.flatMap((group) => group.tags)),
    ];
  }

  get header() {
    return this.isEditing
      ? "admin.rss_polling.feeds.edit_header"
      : "admin.rss_polling.feeds.add_header";
  }

  get formData() {
    const feed = this.args.feed;

    if (!feed) {
      return {};
    }

    return {
      feed_url: feed.feed_url,
      feed_category_filter: feed.feed_category_filter,
      author_username: feed.author ? [feed.author.username] : [],
      discourse_category_id: feed.discourse_category_id,
      discourse_tags: feed.discourse_tags,
    };
  }

  get testErrorMessage() {
    return errorMessage(this.testError);
  }

  get previewCounts() {
    return previewSummary(this.testResults);
  }

  @action
  dismissTest() {
    this.testResults = null;
    this.testError = null;
  }

  @action
  markDirty() {
    this.dirty = true;
  }

  get pollNowTitle() {
    if (this.dirty) {
      return "admin.rss_polling.history.poll_now_dirty";
    }

    if (!this.feedToggle.enabled) {
      return "admin.rss_polling.history.poll_now_disabled";
    }

    return null;
  }

  @action
  pollNow() {
    this.dialog.confirm({
      message: i18n("admin.rss_polling.history.poll_confirm"),
      didConfirm: async () => {
        this.polling = true;

        try {
          await RssPollingFeedSettings.pollNow(this.args.feed.id);
          this.toasts.success({
            duration: "short",
            data: { message: i18n("admin.rss_polling.history.poll_started") },
          });
        } catch (error) {
          popupAjaxError(error);
        } finally {
          this.polling = false;
        }
      },
    });
  }

  loadCategoryRequirements(categoryId) {
    this.#requirementsLoaded = (async () => {
      if (!categoryId) {
        this.categoryRequirements = [];
        return;
      }

      try {
        const result =
          await RssPollingFeedSettings.categoryRequirements(categoryId);
        this.categoryRequirements = result.required_tag_groups ?? [];
      } catch {
        this.categoryRequirements = [];
      }
    })();

    return this.#requirementsLoaded;
  }

  @action
  categoryChanged(field, categoryId) {
    field.set(categoryId);
    this.loadCategoryRequirements(categoryId);
  }

  @action
  async validateForm(data, { addError }) {
    await this.#requirementsLoaded;

    if (data.feed_url && !isHttpUrl(data.feed_url)) {
      addError("feed_url", {
        title: i18n("admin.rss_polling.feed_url"),
        message: i18n("admin.rss_polling.feed_url_must_be_http"),
      });
    }

    const feedTags = data.discourse_tags ?? [];

    this.categoryRequirements.forEach((group) => {
      const matched = group.tags.filter((tag) => feedTags.includes(tag)).length;
      if (matched < group.min_count) {
        addError("discourse_tags", {
          title: i18n("admin.rss_polling.discourse_tags"),
          message: i18n("admin.rss_polling.required_tag_error", {
            count: group.min_count,
            tag_group: group.tag_group,
          }),
        });
      }
    });
  }

  @action
  async save(data) {
    this.submitting = true;

    try {
      const result = await RssPollingFeedSettings.updateFeed({
        id: this.args.feed?.id,
        feed_url: data.feed_url,
        feed_category_filter: data.feed_category_filter,
        author_username: data.author_username?.[0],
        discourse_category_id: data.discourse_category_id,
        discourse_tags: data.discourse_tags,
      });

      this.toasts.success({
        duration: "short",
        data: { message: i18n("admin.rss_polling.feeds.save_success") },
      });

      this.dismissTest();
      this.dirty = false;

      if (!this.isEditing) {
        this.router.transitionTo(
          "adminPlugins.show.discourse-rss-polling-feeds.edit",
          result.id
        );
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.submitting = false;
    }
  }

  @action
  async testFeed(data) {
    this.testing = true;
    this.testError = null;
    this.testResults = null;

    try {
      const result = await RssPollingFeedSettings.testFeed(data);

      this.testTotal = result.total;
      this.testResults = result.items;
    } catch (error) {
      const key = error?.jqXHR?.responseJSON?.error;
      if (key) {
        this.testError = key;
      } else {
        popupAjaxError(error);
      }
    } finally {
      this.testing = false;
    }
  }

  <template>
    <AdminConfigAreaCard @heading={{this.header}} class="rss-polling-feed-form">
      <:headerAction>
        {{#if this.isEditing}}
          <div class="rss-polling-feed-form__enabled-control">
            <DToggleSwitch
              @state={{this.feedToggle.enabled}}
              aria-label={{if
                this.feedToggle.enabled
                (i18n "admin.rss_polling.feeds.disable")
                (i18n "admin.rss_polling.feeds.enable")
              }}
              class="rss-polling-feed-form__toggle"
              {{on "click" this.feedToggle.toggle}}
            />
            <span
              class="rss-polling-feed-form__enabled"
              title={{unless
                this.feedToggle.enabled
                (i18n "admin.rss_polling.status.disabled_note")
              }}
            >
              {{if
                this.feedToggle.enabled
                (i18n "admin.rss_polling.status.enabled")
                (i18n "admin.rss_polling.status.disabled")
              }}
            </span>
          </div>
        {{/if}}
      </:headerAction>
      <:content>
        <Form
          @onSubmit={{this.save}}
          @validate={{this.validateForm}}
          @onSet={{this.markDirty}}
          @data={{this.formData}}
          as |form transientData|
        >
          <form.Fieldset @title={{i18n "admin.rss_polling.feed_settings"}}>
            <form.Field
              @name="feed_url"
              @title={{i18n "admin.rss_polling.feed_url"}}
              @validation="required"
              @format="full"
              @type="input-url"
              as |field|
            >
              <field.Control placeholder="https://blog.example.com/feed" />
            </form.Field>

            <form.Field
              @name="feed_category_filter"
              @title={{i18n "admin.rss_polling.feed_category_filter"}}
              @description={{i18n
                "admin.rss_polling.feed_category_filter_description"
              }}
              @format="full"
              @type="input"
              as |field|
            >
              <field.Control />
            </form.Field>
          </form.Fieldset>

          <form.Fieldset @title={{i18n "admin.rss_polling.discourse_settings"}}>
            <div class="rss-polling-feed-form__discourse-fields">
              <form.Field
                @name="author_username"
                @title={{i18n "admin.rss_polling.author"}}
                @validation="required"
                @format="full"
                @type="custom"
                as |field|
              >
                <field.Control>
                  <UserChooser
                    @value={{field.value}}
                    @onChange={{field.set}}
                    @options={{hash maximum=1 excludeCurrentUser=false}}
                    class="rss-polling-feed-form__author"
                  />
                </field.Control>
              </form.Field>

              <form.Field
                @name="discourse_category_id"
                @title={{i18n "admin.rss_polling.discourse_category"}}
                @format="full"
                @type="custom"
                as |field|
              >
                <field.Control>
                  <CategoryChooser
                    @value={{field.value}}
                    @onChange={{fn this.categoryChanged field}}
                    class="rss-polling-feed-form__category"
                  />
                </field.Control>
              </form.Field>

              <form.Field
                @name="discourse_tags"
                @title={{i18n "admin.rss_polling.discourse_tags"}}
                @format="full"
                @type="custom"
                as |field|
              >
                <field.Control>
                  <TagChooser
                    @tags={{field.value}}
                    @allowCreate={{false}}
                    @everyTag={{true}}
                    @unlimitedTagCount={{true}}
                    @onChange={{field.set}}
                    class="rss-polling-feed-form__tags"
                  />
                </field.Control>
                {{#if this.requiredTagNames.length}}
                  <div class="rss-polling-feed-form__tag-requirement">
                    <span>{{i18n "admin.rss_polling.required_tags_hint"}}</span>
                    {{#each this.requiredTagNames as |tag|}}
                      {{dDiscourseTag tag}}
                    {{/each}}
                  </div>
                {{/if}}
              </form.Field>
            </div>
          </form.Fieldset>

          <div class="rss-polling-feed-form__buttons">
            <DButton
              @icon="check"
              @label="admin.rss_polling.feeds.save"
              @isLoading={{this.submitting}}
              type="submit"
              class="btn-primary form-kit__button rss-polling-feed-form__save"
            />
            <DButton
              @action={{fn this.testFeed transientData}}
              @icon="paper-plane"
              @label="admin.rss_polling.test.button"
              @isLoading={{this.testing}}
              class="btn-default rss-polling-feed-form__test"
            />

            {{#if this.isEditing}}
              <DButtonTooltip>
                <:button>
                  <DButton
                    @action={{this.pollNow}}
                    @icon="arrows-rotate"
                    @label="admin.rss_polling.history.poll_now"
                    @isLoading={{this.polling}}
                    @disabled={{or
                      this.dirty
                      this.testing
                      (not this.feedToggle.enabled)
                    }}
                    class="btn-default rss-polling-feed-form__poll"
                  />
                </:button>
                <:tooltip>
                  {{#if this.pollNowTitle}}
                    <DTooltip
                      @icon="circle-info"
                      @content={{i18n this.pollNowTitle}}
                    />
                  {{/if}}
                </:tooltip>
              </DButtonTooltip>
            {{/if}}
          </div>
        </Form>

        {{#if this.testError}}
          <div class="alert alert-error rss-polling-feed-test__error">
            <span>{{this.testErrorMessage}}</span>
            <DButton
              @action={{this.dismissTest}}
              @icon="xmark"
              @title="admin.rss_polling.test.dismiss"
              class="btn-flat btn-small rss-polling-feed-test__dismiss"
            />
          </div>
        {{else if this.testResults}}
          <div class="rss-polling-feed-test">
            <div class="rss-polling-feed-test__header">
              <h3 class="rss-polling-feed-test__title">
                {{i18n "admin.rss_polling.test.title"}}
              </h3>
              {{#if this.previewCounts}}
                <span class="rss-polling-feed-test__count">
                  {{this.previewCounts}}
                </span>
              {{/if}}
              <DButton
                @action={{this.dismissTest}}
                @icon="xmark"
                @label="admin.rss_polling.test.dismiss"
                class="btn-flat btn-small rss-polling-feed-test__dismiss"
              />
            </div>

            {{#if this.testResults.length}}
              <div class="rss-polling-feed-test__panel">
                <RssPollingFeedItemList
                  @items={{this.testResults}}
                  @total={{this.testTotal}}
                />
              </div>
            {{else}}
              <p class="rss-polling-feed-test__empty">
                {{i18n "admin.rss_polling.test.empty"}}
              </p>
            {{/if}}
          </div>
        {{/if}}
      </:content>
    </AdminConfigAreaCard>
  </template>
}
