import BackButton from "discourse/components/back-button";
import RssPollingFeedForm from "discourse/plugins/discourse-rss-polling/discourse/components/rss-polling-feed-form";

export default <template>
  <BackButton
    @route="adminPlugins.show.discourse-rss-polling-feeds"
    @label="admin.rss_polling.feeds.back"
  />
  <div class="rss-polling-feed-editor">
    <RssPollingFeedForm />
  </div>
</template>
