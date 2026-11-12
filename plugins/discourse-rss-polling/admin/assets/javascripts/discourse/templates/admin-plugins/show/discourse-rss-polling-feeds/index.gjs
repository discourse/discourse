import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import RssPollingFeedRow from "discourse/plugins/discourse-rss-polling/discourse/components/rss-polling-feed-row";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "admin.rss_polling.feeds.title"}}
    @path="/admin/plugins/discourse-rss-polling/feeds"
  />

  <section class="admin-detail">
    <DPageSubheader
      @descriptionLabel={{i18n "admin.rss_polling.feeds.description"}}
      @titleLabel={{i18n "admin.rss_polling.feeds.title"}}
    >
      <:actions as |actions|>
        {{#if @controller.feeds.length}}
          <actions.Primary
            class="rss-polling-feeds__add"
            @icon="plus"
            @label="admin.rss_polling.feeds.add"
            @route="adminPlugins.show.discourse-rss-polling-feeds.new"
            @title="admin.rss_polling.feeds.add"
          />
        {{/if}}
      </:actions>
    </DPageSubheader>

    {{#if @controller.feeds.length}}
      <table class="d-table rss-polling-feeds">
        <tbody class="d-table__body">
          {{#each @controller.feeds as |feed|}}
            <RssPollingFeedRow
              @deleteFeed={{@controller.deleteFeed}}
              @feed={{feed}}
            />
          {{/each}}
        </tbody>
      </table>
    {{else}}
      <AdminConfigAreaEmptyList
        @ctaClass="rss-polling-feeds__add"
        @ctaLabel="admin.rss_polling.feeds.add"
        @ctaRoute="adminPlugins.show.discourse-rss-polling-feeds.new"
        @emptyLabel="admin.rss_polling.feeds.empty"
      />
    {{/if}}
  </section>
</template>
