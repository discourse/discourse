import Component from "@glimmer/component";
import { array, concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import ThemeCardPreview from "discourse/components/theme-card-preview";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import BlogThemeThumbnail from "./blog-theme-thumbnail.gjs";

export default class BlogThemeCard extends Component {
  @service blogThemeActions;
  @service router;

  /** The names of the blogs showing this theme, on the plugin-wide themes list. */
  get activeOnLabel() {
    if (!this.args.activeOn?.length) {
      return null;
    }
    return i18n("blog.admin.active_on", {
      blogs: this.args.activeOn.join(", "),
    });
  }

  get isActive() {
    return this.args.theme.id === this.args.activeThemeId;
  }

  // The blog already shows its active theme, unless a newer revision awaits.
  get canPreviewOnBlog() {
    return !this.isActive || this.isOutdated;
  }

  // On a blog's tab, its up-to-date active theme has nothing to do.
  get hasControls() {
    return !this.args.blog || this.canPreviewOnBlog;
  }

  get isInUse() {
    return this.isActive || this.args.activeOn?.length > 0;
  }

  // A blog keeps the snapshot it activated, so later edits need re-activating.
  get isOutdated() {
    return (
      this.isActive &&
      !this.args.theme.preset &&
      this.args.activeRevision < this.args.theme.revision
    );
  }

  @action
  activate() {
    this.blogThemeActions.activate(this.args.theme, {
      blog: this.args.blog,
      onActivated: () => this.router.refresh(),
    });
  }

  @action
  pull() {
    this.blogThemeActions.pull(this.args.theme, {
      onPulled: () => this.router.refresh(),
    });
  }

  @action
  remove() {
    this.blogThemeActions.remove(this.args.theme, {
      onRemoved: () => this.router.refresh(),
    });
  }

  <template>
    <AdminConfigAreaCard
      class={{dConcatClass
        "theme-card blog-theme-card"
        (if this.isActive "--active")
        (if @theme.preset "--preset")
      }}
      data-theme-id={{@theme.id}}
    >
      <:content>
        <ThemeCardPreview @theme={{@theme}}>
          <:placeholder>
            <BlogThemeThumbnail @theme={{@theme}} />
          </:placeholder>

          <:title>
            {{#if @theme.preset}}
              <span class="theme-card__title">{{@theme.name}}</span>
              {{! ThemeCardPreview renders @theme.description itself. }}
              {{#unless @theme.description}}
                <p class="theme-card__description">{{i18n
                    "blog.admin.preset_description"
                  }}</p>
              {{/unless}}
            {{else if @blog}}
              <span class="theme-card__title">{{@theme.name}}</span>
              <p class="theme-card__description">{{i18n "blog.admin.revision"}}
                {{@theme.revision}}</p>
            {{else}}
              <LinkTo
                class="theme-card__title"
                @model={{@theme.id}}
                @route="adminPlugins.show.discourse-blog-themes.edit"
              >{{@theme.name}}</LinkTo>
              <p class="theme-card__description">{{i18n "blog.admin.revision"}}
                {{@theme.revision}}</p>
            {{/if}}
          </:title>

          <:footer>
            <div class="theme-card__footer">
              <div class="theme-card__badges">
                {{#if this.activeOnLabel}}
                  <span class="theme-card__badge --active">{{dIcon
                      "circle-check"
                    }}
                    {{this.activeOnLabel}}</span>
                {{else if this.isActive}}
                  <span class="theme-card__badge --active">{{dIcon
                      "circle-check"
                    }}
                    {{i18n "blog.admin.active"}}</span>
                {{/if}}
                {{#if @theme.locally_modified}}
                  <span class="theme-card__badge">{{dIcon "pencil"}}
                    {{i18n "blog.admin.local_edits_badge"}}</span>
                {{/if}}
              </div>

              {{#if this.hasControls}}
                <div class="theme-card__controls">
                  {{#if this.isOutdated}}
                    <DButton
                      class="btn-primary theme-card__button update"
                      @action={{this.activate}}
                      @translatedLabel={{i18n
                        "blog.admin.update_to_revision"
                        revision=@theme.revision
                      }}
                    />
                  {{/if}}
                  {{#if @blog}}
                    {{! A blog only picks a theme; the library is edited on the Themes tab. }}
                    {{#unless this.isActive}}
                      <DButton
                        class="btn-default theme-card__button activate"
                        @action={{this.activate}}
                        @translatedLabel={{i18n "blog.admin.select_theme"}}
                      />
                    {{/unless}}
                    {{#if this.canPreviewOnBlog}}
                      <a
                        class="btn btn-transparent theme-card__button preview"
                        href={{@theme.preview_url}}
                        rel="noopener noreferrer"
                        target="_blank"
                      >{{dIcon "eye"}}
                        {{i18n "blog.admin.preview"}}</a>
                    {{/if}}
                  {{else if @theme.preset}}
                    <LinkTo
                      class="btn btn-default btn-text theme-card__button customize"
                      @query={{hash from=@theme.id}}
                      @route="adminPlugins.show.discourse-blog-themes.new"
                    >{{i18n "blog.admin.customize"}}</LinkTo>
                  {{else}}
                    <DButton
                      class="btn-default theme-card__button edit"
                      @preventFocus={{true}}
                      @route="adminPlugins.show.discourse-blog-themes.edit"
                      @routeModels={{array @theme.id}}
                      @translatedLabel={{i18n "blog.admin.edit"}}
                    />
                  {{/if}}

                  {{#unless @blog}}
                    <div class="theme-card__footer-actions">
                      <DMenu
                        @icon="ellipsis"
                        @identifier={{concat "blog-theme-actions-" @theme.id}}
                        @modalForMobile={{true}}
                        @title={{i18n "blog.admin.theme_actions"}}
                        @triggerClass="theme-card__footer-menu btn-flat"
                      >
                        <:content>
                          <DDropdownMenu as |dropdown|>
                            {{#unless @hideActivate}}
                              <dropdown.item>
                                <DButton
                                  class="theme-card__button btn-transparent activate"
                                  @action={{this.activate}}
                                  @disabled={{this.isActive}}
                                  @icon="play"
                                  @preventFocus={{true}}
                                  @translatedLabel={{i18n
                                    "blog.admin.activate"
                                  }}
                                />
                              </dropdown.item>
                            {{/unless}}

                            {{#if @theme.source}}
                              <dropdown.item>
                                <DButton
                                  class="theme-card__button btn-transparent"
                                  @action={{this.pull}}
                                  @icon="cloud-arrow-down"
                                  @preventFocus={{true}}
                                  @translatedLabel={{i18n
                                    "blog.admin.pull_git"
                                  }}
                                />
                              </dropdown.item>
                            {{/if}}

                            <dropdown.item>
                              <a
                                class="btn btn-transparent theme-card__button preview"
                                href={{@theme.preview_url}}
                                rel="noopener noreferrer"
                                target="_blank"
                              >{{dIcon "eye"}}
                                {{i18n "blog.admin.preview"}}</a>
                            </dropdown.item>

                            {{#unless @theme.preset}}
                              <dropdown.item>
                                <DButton
                                  class="theme-card__button btn-transparent --danger"
                                  @action={{this.remove}}
                                  @disabled={{this.isInUse}}
                                  @icon="trash-can"
                                  @preventFocus={{true}}
                                  @translatedLabel={{i18n
                                    "blog.admin.delete_theme"
                                  }}
                                />
                              </dropdown.item>
                            {{/unless}}
                          </DDropdownMenu>
                        </:content>
                      </DMenu>
                    </div>
                  {{/unless}}
                </div>
              {{/if}}
            </div>
          </:footer>
        </ThemeCardPreview>
      </:content>
    </AdminConfigAreaCard>
  </template>
}
