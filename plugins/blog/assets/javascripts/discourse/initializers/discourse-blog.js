import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import BlogPublicationPanel from "../components/blog-publication-panel.gjs";

export default {
  name: "discourse-blog",

  initialize(container) {
    const appEvents = container.lookup("service:app-events");
    const settings = container.lookup("service:site-settings");
    if (!settings.blog_enabled) {
      return;
    }
    withPluginApi((api) => {
      if (api.getCurrentUser()?.can_blog_edit ?? api.getCurrentUser()?.staff) {
        api.addCommunitySectionLink({
          name: "blog-editor",
          route: "blog-editor",
          icon: "pen-to-square",
          title: i18n("blog.editor_title"),
          text: i18n("blog.editor_title"),
        });
      }
      api.renderInOutlet("topic-above-post-stream", BlogPublicationPanel);
      // Article titles like "Contact" are shorter than a forum topic title needs to be.
      const blogCategoryIds = [
        settings.blog_category,
        settings.blog_drafts_category,
      ]
        .map((id) => parseInt(id, 10))
        .filter(Boolean);
      api.registerValueTransformer(
        "composer-minimum-title-length",
        ({ value, context }) =>
          blogCategoryIds.includes(context.composer.categoryId) ? 1 : value
      );
      // Inline title edits don't fire an app event, so tell the panel to recheck its status.
      api.registerBehaviorTransformer(
        "topic-controller:finished-editing",
        async ({ next, context }) => {
          const result = await next();
          appEvents.trigger("blog:topic-edited", context.model?.id);
          return result;
        }
      );
    });
  },
};
