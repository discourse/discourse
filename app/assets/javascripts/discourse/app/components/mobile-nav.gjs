import Component from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { classNames, tagName } from "@ember-decorators/component";
import { on as onEvent } from "@ember-decorators/object";
import $ from "jquery";
import icon from "discourse/helpers/d-icon";

@tagName("ul")
@classNames("mobile-nav")
export default class MobileNav extends Component {
  @service router;

  selectedHtml = null;

  @onEvent("init")
  _init() {
    if (this.site.desktopView) {
      let classes = this.desktopClass;
      if (classes) {
        classes = classes.split(" ");
        this.set("classNames", classes);
      }
    }
  }

  currentRouteChanged() {
    this.set("expanded", false);
    next(() => this._updateSelectedHtml());
  }

  _updateSelectedHtml() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    const active = this.element.querySelector(".active");
    if (active && active.innerHTML) {
      this.set("selectedHtml", active.innerHTML);
    }
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    this._updateSelectedHtml();
    this.router.on("routeDidChange", this, this.currentRouteChanged);
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this.router.off("routeDidChange", this, this.currentRouteChanged);
  }

  @action
  toggleExpanded(event) {
    event?.preventDefault();
    this.toggleProperty("expanded");

    next(() => {
      if (this.expanded) {
        $(window)
          .off("click.mobile-nav")
          .on("click.mobile-nav", (e) => {
            if (!this.element || this.isDestroying || this.isDestroyed) {
              return;
            }

            const expander = this.element.querySelector(".expander");
            if (expander && e.target !== expander) {
              this.set("expanded", false);
              $(window).off("click.mobile-nav");
            }
          });
      }
    });
  }

  <template>
    {{#if this.site.mobileView}}
      {{#if this.selectedHtml}}
        <li>
          <a href {{on "click" this.toggleExpanded}} class="expander">
            <span class="selection">{{htmlSafe this.selectedHtml}}</span>
            {{icon "caret-down"}}
          </a>
        </li>
      {{/if}}
      <ul class="drop {{if this.expanded 'expanded'}}">
        {{yield}}
      </ul>
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
