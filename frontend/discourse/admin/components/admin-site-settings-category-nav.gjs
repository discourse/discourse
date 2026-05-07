import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { LinkTo } from "@ember/routing";
import { next } from "@ember/runloop";
import concatClass from "discourse/helpers/concat-class";
import { waitForAnimationEnd } from "discourse/lib/animation-utils";

export default class AdminSiteSettingsCategoryNav extends Component {
  get categories() {
    return this.args.categories ?? this.args.data?.categories ?? [];
  }

  get filtersApplied() {
    return this.args.filtersApplied ?? this.args.data?.filtersApplied ?? false;
  }

  @action
  onLinkClick() {
    next(() => this.args.close?.());
  }

  @action
  async scrollToActive(element) {
    const modalContainer = element.closest(".d-modal__container");
    if (modalContainer) {
      await waitForAnimationEnd(modalContainer);
    }
    element.querySelector("a.active")?.scrollIntoView({ block: "center" });
  }

  <template>
    <ul
      class="nav nav-stacked admin-site-settings-category-nav__list"
      {{didInsert this.scrollToActive}}
    >
      {{#each this.categories as |category|}}
        <li
          class={{concatClass
            "admin-site-settings-category-nav__item"
            category.nameKey
          }}
        >
          <LinkTo
            @route="adminSiteSettingsCategory"
            @model={{category.nameKey}}
            class={{category.nameKey}}
            title={{category.name}}
            {{on "click" this.onLinkClick}}
          >
            {{category.name}}
            {{#if this.filtersApplied}}
              <span class="count">({{category.count}})</span>
            {{/if}}
          </LinkTo>
        </li>
      {{/each}}
    </ul>
  </template>
}
