import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import RssPollingFeedRow from "discourse/plugins/discourse-rss-polling/discourse/components/rss-polling-feed-row";

export default <template>
  <DBreadcrumbsItem
    @path="/admin/plugins/discourse-rss-polling/feeds"
    @label={{i18n "admin.rss_polling.feeds.title"}}
  />

  <section class="admin-detail">
    <DPageSubheader
      @titleLabel={{i18n "admin.rss_polling.feeds.title"}}
      @descriptionLabel={{i18n "admin.rss_polling.feeds.description"}}
    >
      <:actions as |actions|>
        {{#if @controller.feeds.length}}
          <actions.Primary
            @route="adminPlugins.show.discourse-rss-polling-feeds.new"
            @icon="plus"
            @label="admin.rss_polling.feeds.add"
            @title="admin.rss_polling.feeds.add"
            class="rss-polling-feeds__add"
          />
        {{/if}}
      </:actions>
    </DPageSubheader>

    {{#if @controller.feeds.length}}
      <table class="d-table rss-polling-feeds">
        <thead class="d-table__header">
          <tr>
            <th class="d-table__header-cell">{{i18n
                "admin.rss_polling.feed_url"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "admin.rss_polling.feed_category_filter"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "admin.rss_polling.author"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "admin.rss_polling.discourse_category"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "admin.rss_polling.discourse_tags"
              }}</th>
            <th class="d-table__header-cell"></th>
          </tr>
        </thead>
        <tbody class="d-table__body">
          {{#each @controller.feeds as |feed|}}
            <RssPollingFeedRow
              @feed={{feed}}
              @deleteFeed={{@controller.deleteFeed}}
            />
          {{/each}}
        </tbody>
      </table>
    {{else}}
      <div class="admin-config-area-empty-list">
        <span class="admin-config-area-empty-list__title">
          {{i18n "admin.rss_polling.feeds.empty"}}
        </span>
        <DButton
          @route="adminPlugins.show.discourse-rss-polling-feeds.new"
          @icon="plus"
          @label="admin.rss_polling.feeds.add"
          @title="admin.rss_polling.feeds.add"
          class="btn-primary admin-config-area-empty-list__cta-button rss-polling-feeds__add"
        />
      </div>
    {{/if}}
  </section>
</template>
