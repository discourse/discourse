import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import UserChooser from "discourse/select-kit/components/user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  defaultBlog,
  findBlog,
} from "discourse/plugins/blog/discourse/lib/site-blogs";

function withoutSlash(path) {
  return path.replace(/^\/+/, "");
}

export default class BlogArticleSettings extends Component {
  @service dialog;
  @service site;

  @tracked kind = this.#savedKind;
  @tracked saving = false;
  data = this.#snapshot();
  #form;
  #suggestedPath = this.data.path;

  get publication() {
    return this.args.model.publication;
  }

  get isArticle() {
    return this.kind === "article";
  }

  get title() {
    return i18n(
      this.isArticle ? "blog.panel.settings" : "blog.panel.page_settings"
    );
  }

  get canPickBlog() {
    return this.site.blogs?.length > 1 && this.publication.can_change_blog;
  }

  get pathHint() {
    const blog = findBlog(this.site, this.publication.blog_id);
    return this.isArticle && /\{(year|month|day)\}/.test(blog?.path_format)
      ? i18n("blog.path_hint_dated")
      : i18n("blog.path_hint");
  }

  get #savedKind() {
    return this.args.model.publication.page ? "page" : "article";
  }

  @action
  pathPrefix(blogId) {
    const blog = findBlog(this.site, blogId) || defaultBlog(this.site);
    if (!blog) {
      return "/";
    }
    const url = new URL(blog.base_url, window.location.origin);
    return `${url.host}${url.pathname.replace(/\/$/, "")}/`;
  }

  @action
  registerForm(api) {
    this.#form = api;
  }

  @action
  setKind(kind) {
    this.kind = kind;
    const suggestion = this.publication.generated_paths?.[kind];
    if (!suggestion || this.#form.get("path") !== this.#suggestedPath) {
      return;
    }
    this.#suggestedPath = withoutSlash(suggestion);
    this.#form.set("path", this.#suggestedPath);
  }

  @action
  submitForm() {
    return this.#form.submit();
  }

  @action
  confirmClose() {
    if (!this.#form?.isDirty && this.kind === this.#savedKind) {
      return true;
    }
    return this.dialog.confirm({
      message: i18n("blog.article_settings.discard_confirm"),
    });
  }

  @action
  setCover(upload, { set }) {
    set("cover_upload_id", upload?.id ?? "");
    set("cover_url", upload?.url ?? "");
  }

  @action
  async save(data) {
    this.saving = true;
    try {
      const typed = withoutSlash(data.path);
      // An untouched suggestion is sent as the saved path, so it keeps following the title.
      const path =
        typed === this.#suggestedPath ? this.publication.path : `/${typed}`;
      if (
        await this.args.model.onSave({ ...data, path, page: !this.isArticle })
      ) {
        this.args.closeModal();
      }
    } finally {
      this.saving = false;
    }
  }

  #snapshot() {
    const publication = this.args.model.publication;
    return {
      blog_id: publication.blog_id,
      path: withoutSlash(publication.path),
      excerpt: publication.excerpt || "",
      meta_description: publication.meta_description || "",
      canonical_url: publication.canonical_url || "",
      cover_upload_id: publication.cover_upload_id || "",
      cover_url: publication.cover_url || "",
      cover_alt: publication.cover_alt || "",
      co_authors: publication.co_authors || [],
      featured: publication.featured,
      published_at: publication.published_at?.slice(0, 10) || "",
    };
  }

  <template>
    <DModal
      class="blog-article-settings"
      @beforeClose={{this.confirmClose}}
      @closeModal={{@closeModal}}
      @title={{this.title}}
    >
      <:body>
        <Form
          class="blog-article-settings__form"
          @data={{this.data}}
          @onRegisterApi={{this.registerForm}}
          @onSubmit={{this.save}}
          as |form draft|
        >
          <form.Container class="--radio-cards" @format="full">
            <form.ConditionalContent
              @activeName={{this.kind}}
              @onChange={{this.setKind}}
              as |conditional|
            >
              <conditional.Conditions as |Condition|>
                <Condition @name="article">
                  {{dIcon "check"}}
                  {{i18n "blog.article_settings.kind_article"}}
                </Condition>
                <Condition @name="page">
                  {{dIcon "check"}}
                  {{i18n "blog.article_settings.kind_page"}}
                </Condition>
              </conditional.Conditions>
            </form.ConditionalContent>
          </form.Container>
          {{#if this.canPickBlog}}
            <form.Field
              @description={{i18n "blog.blog_field_hint"}}
              @format="full"
              @name="blog_id"
              @title={{i18n "blog.blog_field"}}
              @type="select"
              as |field|
            >
              <field.Control @includeNone={{false}} as |select|>
                {{#each this.site.blogs as |blog|}}
                  <select.Option
                    @value={{blog.id}}
                  >{{blog.name}}</select.Option>
                {{/each}}
              </field.Control>
            </form.Field>
          {{/if}}
          <form.Field
            @description={{this.pathHint}}
            @format="full"
            @name="path"
            @title={{i18n "blog.path"}}
            @type="input"
            @validation="required"
            as |field|
          ><field.Control
              maxlength="240"
              @before={{this.pathPrefix draft.blog_id}}
            /></form.Field>
          <form.Field
            @description={{i18n "blog.excerpt_hint"}}
            @format="full"
            @name="excerpt"
            @title={{i18n "blog.excerpt"}}
            @type="textarea"
            as |field|
          ><field.Control maxlength="1000" @rows={{3}} /></form.Field>
          <form.Field
            @description={{i18n "blog.cover_hint"}}
            @format="full"
            @name="cover_url"
            @onSet={{this.setCover}}
            @title={{i18n "blog.cover"}}
            @type="image"
            as |field|
          ><field.Control @type="blog_cover" /></form.Field>
          <form.Field
            @description={{i18n "blog.cover_alt_hint"}}
            @format="full"
            @name="cover_alt"
            @title={{i18n "blog.cover_alt"}}
            @type="input"
            as |field|
          ><field.Control maxlength="500" /></form.Field>

          <form.Section @title={{i18n "blog.article_settings.search"}}>
            <form.Field
              @description={{i18n "blog.meta_description_hint"}}
              @format="full"
              @name="meta_description"
              @title={{i18n "blog.meta_description"}}
              @type="textarea"
              as |field|
            ><field.Control maxlength="500" @rows={{2}} /></form.Field>
            <form.Field
              @description={{i18n "blog.canonical_url_hint"}}
              @format="full"
              @name="canonical_url"
              @title={{i18n "blog.canonical_url"}}
              @type="input"
              as |field|
            ><field.Control
                maxlength="1000"
                placeholder={{this.publication.url}}
                @type="url"
              /></form.Field>
          </form.Section>

          {{#if this.isArticle}}
            <form.Section @title={{i18n "blog.article_settings.options"}}>
              <form.Field
                @description={{i18n "blog.co_authors_hint"}}
                @format="full"
                @name="co_authors"
                @title={{i18n "blog.co_authors"}}
                @type="custom"
                as |field|
              >
                <field.Control>
                  <UserChooser
                    @onChange={{field.set}}
                    @options={{hash
                      maximum=10
                      excludedUsernames=@model.coAuthorExclusions
                    }}
                    @value={{field.value}}
                  />
                </field.Control>
              </form.Field>
              <form.Field
                @description={{i18n "blog.date_hint"}}
                @name="published_at"
                @title={{i18n "blog.date"}}
                @type="input"
                as |field|
              ><field.Control @type="date" /></form.Field>
              <form.Field
                @format="full"
                @name="featured"
                @showOptional={{false}}
                @title={{i18n "blog.featured"}}
                @type="toggle"
                as |field|
              ><field.Control /></form.Field>
            </form.Section>
          {{/if}}
        </Form>
      </:body>
      <:footer>
        <DButton
          class="btn-primary blog-article-settings__save"
          @action={{this.submitForm}}
          @disabled={{this.saving}}
          @label="blog.save"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
