import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier as modifierFn } from "ember-modifier";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dCloseOnClickOutside from "discourse/ui-kit/modifiers/d-close-on-click-outside";

export default class MobileNav extends Component {
  @service router;
  @service site;

  @tracked selectedHtml = null;
  @tracked expanded = false;

  // Mirror the active item's markup into the collapsed label, keeping it in
  // sync as the `.active` class moves between links or items are loaded.
  trackSelectedHtml = modifierFn((element) => {
    let current;

    const update = () => {
      const html = element.querySelector(".active")?.innerHTML;
      if (html && html !== current) {
        current = html;
        this.selectedHtml = html;
      }
    };

    update();

    const observer = new MutationObserver(update);
    observer.observe(element, {
      subtree: true,
      childList: true,
      characterData: true,
      attributes: true,
      attributeFilter: ["class"],
    });

    return () => observer.disconnect();
  });

  constructor() {
    super(...arguments);
    this.router.on("routeDidChange", this, this.collapse);
    registerDestructor(this, () => {
      this.router.off("routeDidChange", this, this.collapse);
    });
  }

  get rootClass() {
    if (this.site.mobileView) {
      return "mobile-nav";
    }
    return this.args.desktopClass || "mobile-nav";
  }

  @action
  toggleExpanded(event) {
    event?.preventDefault();
    this.expanded = !this.expanded;
  }

  @action
  collapse() {
    if (this.expanded) {
      this.expanded = false;
    }
  }

  <template>
    <ul
      class={{this.rootClass}}
      {{dCloseOnClickOutside this.collapse}}
      ...attributes
    >
      {{#if this.site.mobileView}}
        {{#if this.selectedHtml}}
          <li>
            <a href {{on "click" this.toggleExpanded}} class="expander">
              <span class="selection">{{trustHTML this.selectedHtml}}</span>
              {{dIcon "angle-down"}}
            </a>
          </li>
        {{/if}}
        <ul
          class="drop {{if this.expanded 'expanded'}}"
          {{this.trackSelectedHtml}}
        >
          {{yield}}
        </ul>
      {{else}}
        {{yield}}
      {{/if}}
    </ul>
  </template>
}
