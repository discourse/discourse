import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import MenuItem from "discourse/components/user-menu/menu-item";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default class UserMenuItemsList extends Component {
  @service session;

  @tracked loading = false;
  @tracked items = [];

  constructor() {
    super(...arguments);
    this.#load();
  }

  get itemsCacheKey() {}

  get showAllHref() {}

  get showAllTitle() {}

  get showDismiss() {
    return false;
  }

  get dismissTitle() {}

  get emptyStateComponent() {
    return "user-menu/items-list-empty-state";
  }

  get resolvedEmptyStateComponent() {
    const component = this.emptyStateComponent;
    if (typeof component === "string") {
      return getOwner(this).resolveRegistration(`component:${component}`);
    } else {
      return component;
    }
  }

  get renderDismissConfirmation() {
    return false;
  }

  async fetchItems() {
    throw new Error(
      `the fetchItems method must be implemented in ${this.constructor.name}`
    );
  }

  async refreshList() {
    await this.#load();
  }

  async #load() {
    const cached = this.#getCachedItems();
    if (cached?.length) {
      this.items = cached;
    } else {
      this.loading = true;
    }
    try {
      const items = await this.fetchItems();
      this.#setCachedItems(items);
      this.items = items;
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(
        `an error occurred when loading items for ${this.constructor.name}`,
        err
      );
    } finally {
      this.loading = false;
    }
  }

  #getCachedItems() {
    const key = this.itemsCacheKey;
    if (key) {
      return this.session[`user-menu-items:${key}`];
    }
  }

  #setCachedItems(newItems) {
    const key = this.itemsCacheKey;
    if (key) {
      this.session.set(`user-menu-items:${key}`, newItems);
    }
  }

  @action
  dismissButtonClick() {
    throw new Error(
      `dismissButtonClick must be implemented in ${this.constructor.name}.`
    );
  }

  <template>
    <PluginOutlet
      @name="before-panel-body"
      @outletArgs={{lazyHash closeUserMenu=@closeUserMenu}}
    />
    {{#if this.loading}}
      <div class="spinner-container">
        <div class="spinner"></div>
      </div>
    {{else if this.items.length}}
      <ul aria-labelledby={{@ariaLabelledby}}>
        {{#each this.items as |item|}}
          <MenuItem @item={{item}} @closeUserMenu={{@closeUserMenu}} />
        {{/each}}
      </ul>
      <div class="panel-body-bottom">
        {{#if this.showAllHref}}
          <DButton
            class="btn-default show-all"
            @href={{this.showAllHref}}
            @translatedAriaLabel={{this.showAllTitle}}
            @translatedTitle={{this.showAllTitle}}
          >
            {{icon "chevron-down" aria-label=this.showAllTitle}}
          </DButton>
        {{/if}}
        {{#if this.showDismiss}}
          <button
            type="button"
            class="btn btn-default notifications-dismiss btn-icon-text"
            title={{this.dismissTitle}}
            {{on "click" this.dismissButtonClick}}
          >
            {{icon "check"}}
            {{i18n "user.dismiss"}}
          </button>
        {{/if}}
        <PluginOutlet
          @name="panel-body-bottom"
          @outletArgs={{lazyHash
            itemsCacheKey=this.itemsCacheKey
            closeUserMenu=@closeUserMenu
            showDismiss=this.showDismiss
            dismissButtonClick=this.dismissButtonClick
          }}
        />
      </div>
    {{else}}
      <PluginOutlet
        @name="user-menu-items-list-empty-state"
        @outletArgs={{lazyHash model=this}}
      >
        <this.resolvedEmptyStateComponent />
      </PluginOutlet>
    {{/if}}
    <PluginOutlet
      @name="after-panel-body"
      @outletArgs={{lazyHash closeUserMenu=@closeUserMenu}}
    />
  </template>
}
