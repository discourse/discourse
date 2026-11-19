import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import BlogPublicationPanel from "../components/blog-publication-panel.gjs";

export default {
  name: "discourse-blog",

  initialize(container) {
    const appEvents = container.lookup("service:app-events");
    const settings = container.lookup("service:site-settings");
    const site = container.lookup("service:site");
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
      // "New draft" records the blog the editor was viewing; drafts keep it too.
      api.serializeOnCreate("blog_id", "blogId");
      api.serializeToDraft("blogId");
      // Article titles like "Contact" are shorter than a forum topic title needs to be.
      // Read the settings each time: the blog creates its categories mid-session.
      api.registerValueTransformer(
        "composer-minimum-title-length",
        ({ value, context }) => {
          const blogCategoryIds = [
            ...(site.blogs || []).map((blog) => blog.category_id),
            parseInt(settings.blog_drafts_category, 10),
          ];
          return blogCategoryIds.includes(context.composer.categoryId)
            ? 1
            : value;
        }
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
