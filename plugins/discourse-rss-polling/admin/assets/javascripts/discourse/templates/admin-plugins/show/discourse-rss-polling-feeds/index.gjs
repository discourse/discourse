import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
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
      <AdminConfigAreaEmptyList
        @emptyLabel="admin.rss_polling.feeds.empty"
        @ctaLabel="admin.rss_polling.feeds.add"
        @ctaRoute="adminPlugins.show.discourse-rss-polling-feeds.new"
        @ctaClass="rss-polling-feeds__add"
      />
    {{/if}}
  </section>
</template>
