import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { defaultBlog } from "discourse/plugins/blog/discourse/lib/site-blogs";

export default class BlogAdminPluginActions extends Component {
  @service site;

  get defaultBlogUrl() {
    return defaultBlog(this.site)?.base_url;
  }

  <template>
    <@actions.Wrapped as |wrapped|>
      <DButton
        class={{if
          wrapped.buttonClass
          wrapped.buttonClass
          "d-page-action-button btn-small btn-default"
        }}
        rel="noopener noreferrer"
        target="_blank"
        @href={{this.defaultBlogUrl}}
        @label="blog.admin.view_blog"
      />
    </@actions.Wrapped>
    <@actions.Primary
      ...attributes
      @label="blog.admin.go_to_editor"
      @route="blog-editor"
    />
  </template>
}
