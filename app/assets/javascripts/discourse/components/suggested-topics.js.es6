import { categoryBadgeHTML } from 'discourse/helpers/category-link';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  loading: false,

  didInsertElement() {
    this._super();

    this.set('loading', true);
    this.set('suggestedTopics', []);

    this.get('model').fetchSuggestedTopics().then(topics => {
      this.set('suggestedTopics', topics);
    }).finally(() => this.set('loading', false));
  },

  @computed('model.isPrivateMessage', 'pmPath')
  suggestedTitle(isPrivateMessage, pmPath) {
    if (isPrivateMessage) {
      return `
        <a href="${pmPath}">
          <i class='private-message-glyph fa fa-envelope'></i>
        </a> ${I18n.t("suggested_topics.pm_title")}
      `;
    } else {
      return I18n.t("suggested_topics.title");
    }
  },

  @computed('model.isPrivateMessage', 'model.category', 'topicTrackingState.messageCount')
  browseMoreMessage(isPrivateMessage, category) {

    // TODO decide what to show for pms
    if (isPrivateMessage) { return; }

    const opts = { latestLink: `<a href="${Discourse.getURL("/latest")}">${I18n.t("topic.view_latest_topics")}</a>` };

    if (category && Em.get(category, 'id') === Discourse.Site.currentProp("uncategorized_category_id")) {
      category = null;
    }

    if (category) {
      opts.catLink = categoryBadgeHTML(category);
    } else {
      opts.catLink = "<a href=\"" + Discourse.getURL("/categories") + "\">" + I18n.t("topic.browse_all_categories") + "</a>";
    }

    const unreadTopics = this.topicTrackingState.countUnread();
    const newTopics = this.topicTrackingState.countNew();

    if (newTopics + unreadTopics > 0) {
      const hasBoth = unreadTopics > 0 && newTopics > 0;

      return I18n.messageFormat("topic.read_more_MF", {
        "BOTH": hasBoth,
        "UNREAD": unreadTopics,
        "NEW": newTopics,
        "CATEGORY": category ? true : false,
        latestLink: opts.latestLink,
        catLink: opts.catLink
      });
    } else if (category) {
      return I18n.t("topic.read_more_in_category", opts);
    } else {
      return I18n.t("topic.read_more", opts);
    }
  }
});
