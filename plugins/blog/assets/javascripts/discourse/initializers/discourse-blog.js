import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import BlogPublicationPanel from "../components/blog-publication-panel.gjs";

export default {
  name: "discourse-blog",

  initialize(container) {
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
    });
  },
};
