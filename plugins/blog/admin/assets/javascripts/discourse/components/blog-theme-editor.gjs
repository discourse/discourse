import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { array, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import AceEditor from "discourse/components/ace-editor";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import DFlashMessage from "discourse/ui-kit/d-flash-message";
import DHighlightedCode from "discourse/ui-kit/d-highlighted-code";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import BlogThemeFields from "./blog-theme-fields.gjs";
import BlogThemePreview from "./modal/blog-theme-preview.gjs";
import BlogThemeVariables from "./modal/blog-theme-variables.gjs";

const TEMPLATE_NAMES = ["layout", "index", "article", "about", "not_found"];

const PAGE_FOR_TEMPLATE = {
  template_index: "index",
  template_article: "article",
  template_about: "about",
  template_not_found: "not_found",
};

export default class BlogThemeEditor extends Component {
  @service router;
  @service dialog;
  @service modal;
  @service toasts;
  @service blogThemeActions;

  @tracked busy = false;
  @tracked tab = "design";
  @tracked catalog;
  @tracked previewUrl;
  @tracked previewDevice = "desktop";
  @tracked selectedArticle;
  @tracked previewPage = "index";
  @tracked catalogError = false;
  @tracked variableQuery = "";
  // FormKit hands its API over after the first render, so this has to be tracked:
  // template state read before then would never re-evaluate.
  @tracked formApi;
  #catalogSequence = 0;
  #previewSequence = 0;

  @cached
  get state() {
    const { theme, active } = this.args.model;
    return trackedObject({
      activeTheme: active,
      draft: theme,
    });
  }

  get exportUrl() {
    return getURL(`/admin/plugins/blog/themes/${this.state.draft.id}/export`);
  }

  get hasUnsavedChanges() {
    return this.formApi?.isDirty;
  }

  get previewUnavailable() {
    return this.previewPage === "article" && !this.selectedArticle;
  }

  get actionsDisabled() {
    return this.busy || this.blogThemeActions.busy || this.hasUnsavedChanges;
  }

  get tabs() {
    return [
      {
        name: "design",
        label: i18n("blog.admin.authoring_design"),
        overridden: false,
      },
      ...this.templateChoices,
    ];
  }

  // Overridden state is read lazily so that tab markers stay live inside the tab nav.
  @cached
  get templateChoices() {
    const editor = this;

    return TEMPLATE_NAMES.map((name) => {
      const field = `template_${name}`;

      return {
        name: field,
        label: i18n(`blog.admin.template_${name}`),
        get overridden() {
          return editor.#overridden(field);
        },
      };
    });
  }

  get currentTemplate() {
    return this.templateChoices.find((item) => item.name === this.tab);
  }

  get effectiveTemplate() {
    if (!this.currentTemplate) {
      return "";
    }

    return (
      this.formApi?.get(this.currentTemplate.name) ||
      this.catalog?.templates[this.currentTemplate.name] ||
      ""
    );
  }

  get articleOptions() {
    return this.catalog?.articles ?? [];
  }

  get variables() {
    const rows = [];
    const visit = (object, prefix = "") => {
      for (const [key, value] of Object.entries(object || {})) {
        if (
          prefix === "labels" &&
          typeof value === "string" &&
          value.includes("%{")
        ) {
          continue;
        }
        const path = prefix ? `${prefix}.${key}` : key;
        if (Array.isArray(value)) {
          rows.push({
            path,
            type: i18n("blog.admin.array_value"),
            example: JSON.stringify(value).slice(0, 350),
            snippet: `{% for item in ${path} %}{{ item.${key === "tags" ? "name" : "title"} }}{% endfor %}`,
          });
        } else if (value && typeof value === "object") {
          visit(value, path);
        } else {
          rows.push({
            path,
            type: path.endsWith("_html")
              ? i18n("blog.admin.trusted_html")
              : i18n("blog.admin.escaped_text"),
            example: String(value ?? "").slice(0, 350),
            snippet: `{{ ${path} }}`,
          });
        }
      }
    };
    const sample = this.catalog?.variables || {};
    visit({
      site: sample.site,
      article: sample.article,
      articles: sample.articles,
      page: sample.page,
      labels: sample.labels,
    });
    rows.unshift({
      path: "content_html",
      type: i18n("blog.admin.trusted_html"),
      example: i18n("blog.admin.layout_content"),
      snippet: "{{ content_html }}",
    });
    return rows.filter((row) =>
      row.path.toLowerCase().includes(this.variableQuery.toLowerCase())
    );
  }

  @action
  filterVariables(event) {
    this.variableQuery = event.target.value;
  }

  @action
  preventSearchSubmit(event) {
    if (event.key === "Enter") {
      event.preventDefault();
    }
  }

  @action
  async selectTab(tab) {
    this.tab = tab;
    if (!this.catalog) {
      await this.loadCatalog();
    }
  }

  @action
  openVariables() {
    this.variableQuery = "";
    this.modal.show(BlogThemeVariables, { model: { editor: this } });
  }

  @action
  async openPreview() {
    const page = PAGE_FOR_TEMPLATE[this.tab];
    if (page) {
      this.previewPage = page;
    }

    if (this.previewUnavailable) {
      this.previewPage = "index";
    }

    if (await this.previewWorking()) {
      this.modal.show(BlogThemePreview, { model: { editor: this } });
    }
  }

  @action
  async selectArticle(value) {
    this.selectedArticle = value;
    await this.loadCatalog();
  }

  @action
  async selectPreviewArticle(value) {
    this.selectedArticle = value;
    await Promise.all([this.loadCatalog(), this.previewWorking()]);
  }

  @action
  async selectPreviewPage(value) {
    this.previewPage = value;
    await this.previewWorking();
  }

  @action
  selectDevice(value) {
    this.previewDevice = value;
  }

  @action
  async loadCatalog() {
    const sequence = ++this.#catalogSequence;
    this.catalogError = false;
    try {
      const catalog = await ajax("/admin/plugins/blog/theme-authoring.json", {
        data: { article_id: this.selectedArticle },
      });
      if (sequence !== this.#catalogSequence || this.isDestroying) {
        return;
      }
      this.catalog = catalog;
      this.selectedArticle ||= catalog.articles[0]?.id;
    } catch (error) {
      if (sequence !== this.#catalogSequence || this.isDestroying) {
        return;
      }
      this.catalogError = true;
      popupAjaxError(error);
    }
  }

  @action
  customize() {
    this.formApi.set(this.currentTemplate.name, this.effectiveTemplate);
  }

  @action
  restoreDefault() {
    this.dialog.confirm({
      message: i18n("blog.admin.restore_confirm"),
      didConfirm: () => {
        this.formApi.set(this.currentTemplate.name, "");
      },
    });
  }

  @action
  insertVariable(variable) {
    if (!this.currentTemplate) {
      return;
    }

    this.formApi.set(
      this.currentTemplate.name,
      `${this.effectiveTemplate}\n${variable.snippet}`
    );
  }

  @action
  async previewWorking() {
    if (this.previewUnavailable) {
      return null;
    }

    const sequence = ++this.#previewSequence;
    this.busy = true;

    try {
      const keys = [
        "name",
        "accent_color",
        "paper_color",
        "ink_color",
        "css",
        "javascript",
        ...this.templateChoices.map((item) => item.name),
      ];
      const theme = Object.fromEntries(
        keys.map((key) => [
          key,
          this.formApi.get(key) ?? this.state.draft[key] ?? "",
        ])
      );
      const result = await ajax(
        "/admin/plugins/blog/theme-authoring/preview.json",
        {
          type: "POST",
          data: {
            theme,
            page: this.previewPage,
            article_id: this.selectedArticle,
          },
        }
      );
      if (sequence === this.#previewSequence) {
        this.previewUrl = result.url;
      }
      return this.previewUrl;
    } catch (error) {
      if (sequence === this.#previewSequence) {
        popupAjaxError(error);
      }
      return null;
    } finally {
      if (sequence === this.#previewSequence) {
        this.busy = false;
      }
    }
  }

  @action
  registerApi(api) {
    // Assigning during the render that reads this field would back-track, so wait
    // for the render pass to finish.
    schedule("afterRender", () => {
      if (this.isDestroying) {
        return;
      }
      this.formApi = api;
      if (!this.catalog) {
        this.loadCatalog();
      }
    });
  }

  @action
  async saveDraft(data) {
    const id = this.state.draft.id;
    const theme = await this.#request(id ? `/${id}` : "", id ? "PUT" : "POST", {
      theme: data,
      revision: this.state.draft.revision,
    });
    if (theme) {
      this.formApi.commit();
      this.#update(theme);
      if (!id) {
        this.router.transitionTo(
          "adminPlugins.show.discourse-blog-themes.edit",
          theme.id
        );
      }
      this.toasts.success({
        data: { message: i18n("blog.admin.draft_saved") },
      });
    }
  }

  @action
  activate() {
    this.blogThemeActions.activate(this.state.draft, {
      onActivated: (active) => (this.state.activeTheme = active),
    });
  }

  @action
  pull() {
    this.blogThemeActions.pull(this.state.draft, {
      onPulled: (updated) => this.#update(updated),
    });
  }

  @action
  remove() {
    this.blogThemeActions.remove(this.state.draft, {
      onRemoved: () =>
        this.router.transitionTo("adminPlugins.show.discourse-blog-themes"),
    });
  }

  #overridden(field) {
    const source = this.formApi?.get(field) ?? this.state.draft[field] ?? "";
    return source.trim().length > 0;
  }

  #update(theme) {
    this.state.draft = theme;
  }

  async #request(path, type, data) {
    this.busy = true;
    try {
      return await ajax(`/admin/plugins/blog/themes${path}.json`, {
        type,
        data,
      });
    } catch (error) {
      popupAjaxError(error);
      return false;
    } finally {
      this.busy = false;
    }
  }

  <template>
    <section class="blog-theme-editor admin-detail" ...attributes>
      <BackButton
        @label="blog.admin.back_to_themes"
        @route="adminPlugins.show.discourse-blog-themes"
      />
      <DPageSubheader
        @descriptionLabel={{i18n "blog.admin.editor_description"}}
        @titleLabel={{this.state.draft.name}}
      >
        <:actions as |actions|>
          {{#if this.state.draft.id}}
            <actions.Wrapped>
              <a
                class="btn btn-default raw-link blog-theme-editor__export"
                download
                href={{this.exportUrl}}
                title={{i18n "blog.admin.export_description"}}
              >{{i18n "blog.admin.export"}}</a>
            </actions.Wrapped>
          {{/if}}
        </:actions>
      </DPageSubheader>

      <div class="admin-controls blog-theme-editor__tabs">
        <DHorizontalOverflowNav
          aria-label={{i18n "blog.admin.authoring_sections"}}
        >
          {{#each this.tabs as |tab|}}
            <li>
              <button
                aria-current={{if (eq this.tab tab.name) "true"}}
                class={{if (eq this.tab tab.name) "active" "blank"}}
                data-authoring-tab={{tab.name}}
                type="button"
                {{on "click" (fn this.selectTab tab.name)}}
              >
                {{tab.label}}
                {{#if tab.overridden}}
                  <span
                    aria-hidden="true"
                    class="blog-theme-editor__marker"
                  ></span>
                  <span class="sr-only">{{i18n "blog.admin.overridden"}}</span>
                {{/if}}
              </button>
            </li>
          {{/each}}
        </DHorizontalOverflowNav>
      </div>

      {{#if this.catalogError}}<DButton
          @action={{this.loadCatalog}}
          @label="blog.admin.retry_reference"
        />{{/if}}
      {{#let this.state.draft as |draft|}}
        <Form
          class="blog-theme-editor__form"
          @commitOnSubmit={{false}}
          @data={{draft}}
          @onRegisterApi={{this.registerApi}}
          @onSubmit={{this.saveDraft}}
          as |form|
        >
          {{#if (eq this.tab "design")}}
            <BlogThemeFields @form={{form}} />
          {{else}}
            <div class="blog-theme-editor__state">
              <p class="blog-theme-editor__state-text">{{#if
                  this.currentTemplate.overridden
                }}{{i18n "blog.admin.template_custom_state"}}{{else}}{{i18n
                    "blog.admin.template_builtin_state"
                  }}{{/if}}</p>
              <div class="blog-theme-editor__state-actions">
                <DButton
                  class="blog-theme-editor__variables"
                  @action={{this.openVariables}}
                  @icon="circle-question"
                  @label="blog.admin.variable_reference"
                />
                {{#if this.currentTemplate.overridden}}
                  <DButton
                    class="blog-theme-editor__restore-default"
                    @action={{this.restoreDefault}}
                    @label="blog.admin.restore_default"
                  />
                {{else}}
                  <DButton
                    class="blog-theme-editor__customize"
                    @action={{this.customize}}
                    @disabled={{not this.catalog}}
                    @label="blog.admin.customize_template"
                  />
                {{/if}}
              </div>
            </div>

            {{#if this.currentTemplate.overridden}}
              {{! Keep the field name stable during teardown when switching tabs. }}
              {{#each (array this.currentTemplate) as |template|}}
                <form.Field
                  class="blog-theme-editor__template-field"
                  @format="full"
                  @name={{template.name}}
                  @showTitle={{false}}
                  @title={{template.label}}
                  @type="custom"
                  as |field|
                >
                  <field.Control>
                    <AceEditor
                      aria-describedby={{field.describedBy}}
                      aria-invalid={{if field.error "true"}}
                      class="blog-theme-editor__template-control"
                      id={{field.id}}
                      name={{field.name}}
                      @content={{field.value}}
                      @disabled={{field.disabled}}
                      @editorId={{field.id}}
                      @mode="html"
                      @onChange={{field.set}}
                      @resizable={{true}}
                    />
                  </field.Control>
                </form.Field>
              {{/each}}
            {{else}}
              <div class="blog-theme-editor__builtin">
                <DHighlightedCode
                  @code={{this.effectiveTemplate}}
                  @lang="html"
                />
              </div>
            {{/if}}
          {{/if}}

          <form.Actions>
            <form.Submit
              @disabled={{this.busy}}
              @label="blog.admin.save_draft"
            />
            <form.Button
              class="blog-theme-editor__preview-draft"
              @action={{this.openPreview}}
              @disabled={{this.busy}}
              @icon="eye"
              @label="blog.admin.preview_short"
            />
            {{#if draft.id}}
              <form.Button
                class="blog-theme-editor__activate"
                @action={{this.activate}}
                @disabled={{this.actionsDisabled}}
                @label="blog.admin.activate_theme"
              />
              <form.Button
                class="blog-theme-editor__delete"
                @action={{this.remove}}
                @disabled={{or
                  this.actionsDisabled
                  (eq draft.id this.state.activeTheme.id)
                }}
                @label="blog.admin.delete_theme"
              />
            {{/if}}
          </form.Actions>
        </Form>
        {{#if this.hasUnsavedChanges}}<p>{{i18n
              "blog.admin.save_before_activate"
            }}</p>{{/if}}
        {{#if draft.source}}
          <details class="blog-theme-editor__source">
            <summary>{{i18n "blog.admin.git_source"}}</summary>
            <p>{{draft.source.repository}}
              ·
              {{draft.source.branch}}
              ·
              <code>{{draft.source.commit}}</code></p>
            {{#if draft.locally_modified}}<DFlashMessage
                @flash={{i18n "blog.admin.local_edits"}}
                @type="info"
              />{{/if}}
            <DButton
              @action={{this.pull}}
              @disabled={{this.actionsDisabled}}
              @label="blog.admin.pull_git"
            />
          </details>
        {{/if}}
      {{/let}}
    </section>
  </template>
}
