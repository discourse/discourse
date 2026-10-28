import Component from "@glimmer/component";
import { array, concat } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import ThemeCardPreview from "discourse/components/theme-card-preview";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import BlogThemeThumbnail from "./blog-theme-thumbnail.gjs";

export default class BlogThemeCard extends Component {
  @service blogThemeActions;
  @service router;

  get isActive() {
    return this.args.theme.id === this.args.activeThemeId;
  }

  @action
  activate() {
    this.blogThemeActions.activate(this.args.theme, {
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
      class="theme-card blog-theme-card"
      data-theme-id={{@theme.id}}
    >
      <:content>
        <ThemeCardPreview @theme={{@theme}}>
          <:placeholder>
            <BlogThemeThumbnail @theme={{@theme}} />
          </:placeholder>

          <:title>
            <LinkTo
              class="theme-card__title"
              @model={{@theme.id}}
              @route="adminPlugins.show.discourse-blog-themes.edit"
            >{{@theme.name}}</LinkTo>
            <p class="theme-card__description">{{i18n "blog.admin.revision"}}
              {{@theme.revision}}</p>
            {{#if (or this.isActive @theme.locally_modified)}}
              <div class="theme-card__badges">
                {{#if this.isActive}}
                  <span class="theme-card__badge">{{dIcon "circle-check"}}
                    {{i18n "blog.admin.active"}}</span>
                {{/if}}
                {{#if @theme.locally_modified}}
                  <span class="theme-card__badge">{{dIcon "pencil"}}
                    {{i18n "blog.admin.local_edits_badge"}}</span>
                {{/if}}
              </div>
            {{/if}}
          </:title>

          <:footer>
            <div class="theme-card__footer">
              <div class="theme-card__controls">
                <DButton
                  class="btn-default theme-card__button edit"
                  @preventFocus={{true}}
                  @route="adminPlugins.show.discourse-blog-themes.edit"
                  @routeModels={{array @theme.id}}
                  @translatedLabel={{i18n "blog.admin.edit"}}
                />

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
                        <dropdown.item>
                          <DButton
                            class="theme-card__button btn-transparent"
                            @action={{this.activate}}
                            @disabled={{this.isActive}}
                            @icon="play"
                            @preventFocus={{true}}
                            @translatedLabel={{i18n "blog.admin.activate"}}
                          />
                        </dropdown.item>

                        {{#if @theme.source}}
                          <dropdown.item>
                            <DButton
                              class="theme-card__button btn-transparent"
                              @action={{this.pull}}
                              @icon="cloud-arrow-down"
                              @preventFocus={{true}}
                              @translatedLabel={{i18n "blog.admin.pull_git"}}
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

                        <dropdown.item>
                          <DButton
                            class="theme-card__button btn-transparent --danger"
                            @action={{this.remove}}
                            @disabled={{this.isActive}}
                            @icon="trash-can"
                            @preventFocus={{true}}
                            @translatedLabel={{i18n "blog.admin.delete_theme"}}
                          />
                        </dropdown.item>
                      </DDropdownMenu>
                    </:content>
                  </DMenu>
                </div>
              </div>
            </div>
          </:footer>
        </ThemeCardPreview>
      </:content>
    </AdminConfigAreaCard>
  </template>
}
