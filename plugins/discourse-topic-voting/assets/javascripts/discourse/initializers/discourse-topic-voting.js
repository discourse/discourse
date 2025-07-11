import { withPluginApi } from "discourse/lib/plugin-api";
import NavItem from "discourse/models/nav-item";
import { i18n } from "discourse-i18n";

export default {
  name: "discourse-topic-voting",

  initialize() {
    withPluginApi((api) => {
      const siteSettings = api.container.lookup("service:site-settings");
      if (siteSettings.topic_voting_enabled) {
        const pageSearchController = api.container.lookup(
          "controller:full-page-search"
        );
        pageSearchController.sortOrders.pushObject({
          name: i18n("search.most_votes"),
          id: 5,
          term: "order:votes",
        });

        api.addNavigationBarItem({
          name: "votes",
          before: "top",
          customFilter: (category) => {
            return category && category.can_vote;
          },
          customHref: (category, args) => {
            const path = NavItem.pathFor("latest", args);
            return `${path}?order=votes`;
          },
          forceActive: (category, args, router) => {
            const queryParams = router.currentRoute.queryParams;
            return (
              queryParams &&
              Object.keys(queryParams).length === 1 &&
              queryParams["order"] === "votes"
            );
          },
        });
        api.addNavigationBarItem({
          name: "my_votes",
          before: "top",
          customFilter: (category) => {
            return category && category.can_vote && api.getCurrentUser();
          },
          customHref: (category, args) => {
            const path = NavItem.pathFor("latest", args);
            return `${path}?state=my_votes`;
          },
          forceActive: (category, args, router) => {
            const queryParams = router.currentRoute.queryParams;
            return (
              queryParams &&
              Object.keys(queryParams).length === 1 &&
              queryParams["state"] === "my_votes"
            );
          },
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
