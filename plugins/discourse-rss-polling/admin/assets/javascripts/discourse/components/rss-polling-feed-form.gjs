import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import UserChooser from "discourse/select-kit/components/user-chooser";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import { i18n } from "discourse-i18n";
import RssPollingFeedItemList from "discourse/plugins/discourse-rss-polling/discourse/components/rss-polling-feed-item-list";
import { errorMessage } from "discourse/plugins/discourse-rss-polling/discourse/lib/rss-polling-item";
import RssPollingFeedSettings from "../../admin/models/rss-polling-feed-settings";

export default class RssPollingFeedForm extends Component {
  @service router;
  @service toasts;

  @tracked testing = false;
  @tracked testResults = null;
  @tracked testTotal = 0;
  @tracked testError = null;
  @tracked categoryRequirements = [];
  #requirementsLoaded = Promise.resolve();

  constructor() {
    super(...arguments);
    this.loadCategoryRequirements(this.args.feed?.discourse_category_id);
  }

  get isEditing() {
    return !!this.args.feed;
  }

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
      author_username: feed.author_username ? [feed.author_username] : [],
      discourse_category_id: feed.discourse_category_id,
      discourse_tags: feed.discourse_tags,
    };
  }

  get testErrorMessage() {
    return errorMessage(this.testError);
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
    try {
      await RssPollingFeedSettings.updateFeed({
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

      this.router.transitionTo("adminPlugins.show.discourse-rss-polling-feeds");
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async testFeed(data) {
    if (!data?.feed_url) {
      return;
    }

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
    <BackButton
      @route="adminPlugins.show.discourse-rss-polling-feeds"
      @label="admin.rss_polling.feeds.back"
    />
    <div class="admin-config-area">
      <div class="admin-config-area__primary-content rss-polling-feed-form">
        <AdminConfigAreaCard @heading={{this.header}}>
          <:content>
            <Form
              @onSubmit={{this.save}}
              @validate={{this.validateForm}}
              @data={{this.formData}}
              as |form transientData|
            >
              <form.Fieldset @title={{i18n "admin.rss_polling.feed_settings"}}>
                <form.Field
                  @name="feed_url"
                  @title={{i18n "admin.rss_polling.feed_url"}}
                  @validation="required"
                  @format="full"
                  @type="input"
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

              <form.Fieldset
                @title={{i18n "admin.rss_polling.discourse_settings"}}
              >
                <form.Field
                  @name="author_username"
                  @title={{i18n "admin.rss_polling.author"}}
                  @description={{i18n "admin.rss_polling.author_description"}}
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
                      <span>{{i18n
                          "admin.rss_polling.required_tags_hint"
                        }}</span>
                      {{#each this.requiredTagNames as |tag|}}
                        {{dDiscourseTag tag}}
                      {{/each}}
                    </div>
                  {{/if}}
                </form.Field>
              </form.Fieldset>

              <div class="rss-polling-feed-form__buttons">
                <form.Submit @label="admin.rss_polling.feeds.save" />
                <DButton
                  @action={{fn this.testFeed transientData}}
                  @icon="paper-plane"
                  @label="admin.rss_polling.test.button"
                  @isLoading={{this.testing}}
                  @disabled={{not transientData.feed_url}}
                  class="btn-default rss-polling-feed-form__test"
                />
              </div>
            </Form>

            {{#if this.testError}}
              <div class="alert alert-error rss-polling-feed-test__error">
                {{this.testErrorMessage}}
              </div>
            {{else if this.testResults}}
              <div class="rss-polling-feed-test">
                <h3 class="rss-polling-feed-test__title">
                  {{i18n "admin.rss_polling.test.title"}}
                </h3>
                {{#if this.testResults.length}}
                  <RssPollingFeedItemList
                    @items={{this.testResults}}
                    @total={{this.testTotal}}
                  />
                {{else}}
                  <p class="rss-polling-feed-test__empty">
                    {{i18n "admin.rss_polling.test.empty"}}
                  </p>
                {{/if}}
              </div>
            {{/if}}
          </:content>
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}
