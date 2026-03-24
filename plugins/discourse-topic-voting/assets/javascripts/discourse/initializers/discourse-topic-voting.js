import { withPluginApi } from "discourse/lib/plugin-api";
import NavItem from "discourse/models/nav-item";
import { i18n } from "discourse-i18n";

export default {
  name: "discourse-topic-voting",

  initialize() {
    withPluginApi((api) => {
      api.registerNotificationTypeRenderer(
        "votes_released",
        (NotificationTypeBase) => {
          return class extends NotificationTypeBase {
            get label() {
              return i18n("topic_voting.notification_label.vote_released");
            }
          };
        }
      );

      const siteSettings = api.container.lookup("service:site-settings");
      if (siteSettings.topic_voting_enabled) {
        const pageSearchController = api.container.lookup(
          "controller:full-page-search"
        );
        pageSearchController.sortOrders.push({
          name: i18n("search.most_votes"),
          id: 5,
          term: "order:votes",
        });

        const addVotingNavItem = (name, param, { requiresUser } = {}) => {
          const [key, value] = param.split("=");
          api.addNavigationBarItem({
            name,
            before: "top",
            customFilter: (category) =>
              category?.can_vote && (!requiresUser || api.getCurrentUser()),
            customHref: (_category, args) =>
              `${NavItem.pathFor("latest", args)}?${param}`,
            forceActive: (_category, _args, router) => {
              const queryParams = router.currentRoute.queryParams;
              return (
                queryParams &&
                Object.keys(queryParams).length === 1 &&
                queryParams[key] === value
              );
            },
          });
        };

        addVotingNavItem("votes", "order=votes");
        addVotingNavItem("votes_trending", "order=votes-trending");
        addVotingNavItem("my_votes", "state=my_votes", {
          requiresUser: true,
        });
      }

      if (siteSettings.topic_voting_enabled) {
        api.addSearchSuggestion("order:votes");
      }

      api.registerValueTransformer(
        "category-available-views",
        ({ value, context }) => {
          if (context.customFields.enable_topic_voting) {
            value.push({
              name: i18n("filters.votes.title"),
              value: "votes",
            });
          }
        }
      );
    });
  },
};
