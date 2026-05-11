import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import escape from "discourse/lib/escape";
import { iconHTML } from "discourse/lib/icon-library";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const MAX_COMPONENTS = 4;

export default class ThemesListItem extends Component {
  @tracked childrenExpanded = false;

  get displayHasMore() {
    return this.args.theme?.get("childThemes.length") > MAX_COMPONENTS;
  }

  get displayComponents() {
    return this.hasComponents && this.args.theme?.isActive;
  }

  get hasComponents() {
    return this.children.length > 0;
  }

  @action
  handleClick(event) {
    if (!event.target.classList.contains("others-count")) {
      this.args.navigateToTheme();
    }
  }

  get children() {
    let children = this.args.theme?.get("childThemes");
    if (this.args.theme?.get("component") || !children) {
      return [];
    }
    children = this.childrenExpanded
      ? children
      : children.slice(0, MAX_COMPONENTS);
    return children.map((t) => {
      const name = escape(t.name);
      return t.enabled ? name : `${iconHTML("ban")} ${name}`;
    });
  }

  get childrenString() {
    return this.children.join(", ");
  }

  get moreCount() {
    const childrenCount = this.args.theme?.get("childThemes.length");
    if (
      this.args.theme?.get("component") ||
      !childrenCount ||
      this.childrenExpanded
    ) {
      return 0;
    }
    return childrenCount - MAX_COMPONENTS;
  }

  @action
  toggleChildrenExpanded(event) {
    event?.preventDefault();
    this.childrenExpanded = !this.childrenExpanded;
  }

  <template>
    {{! template-lint-disable no-nested-interactive }}
    <div
      class={{dConcatClass
        "themes-list-container__item"
        (if @theme.selected "selected")
      }}
      role="button"
      {{on "click" this.handleClick}}
      ...attributes
    >
      <div class="inner-wrapper">
        <span>
          <PluginOutlet
            @name="admin-customize-themes-list-item"
            @connectorTagName="span"
            @outletArgs={{lazyHash theme=@theme}}
          />
        </span>

        <div class="info">
          {{#if @selectInactiveMode}}
            <Input
              @checked={{@theme.markedToDelete}}
              id={{@theme.id}}
              @type="checkbox"
            />
          {{/if}}
          <span class="name">
            {{@theme.name}}
          </span>

          <span class="icons">
            {{#if @theme.selected}}
              {{dIcon "angle-right"}}
            {{else}}
              {{#if @theme.default}}
                {{dIcon
                  "check"
                  class="default-indicator"
                  title="admin.customize.theme.default_theme_tooltip"
                }}
              {{/if}}
              {{#if @theme.isPendingUpdates}}
                {{dIcon
                  "arrows-rotate"
                  title="admin.customize.theme.updates_available_tooltip"
                  class="light-grey-icon"
                }}
              {{/if}}
              {{#if @theme.isBroken}}
                {{dIcon
                  "circle-exclamation"
                  class="broken-indicator"
                  title="admin.customize.theme.broken_theme_tooltip"
                }}
              {{/if}}
              {{#unless @theme.enabled}}
                {{dIcon
                  "ban"
                  class="light-grey-icon"
                  title="admin.customize.theme.disabled_component_tooltip"
                }}
              {{/unless}}
            {{/if}}
          </span>
        </div>

        {{#if this.displayComponents}}
          <div class="components-list">
            <span class="components">{{trustHTML this.childrenString}}</span>

            {{#if this.displayHasMore}}
              <a
                href
                {{on "click" this.toggleChildrenExpanded}}
                class="others-count"
              >
                {{#if this.childrenExpanded}}
                  {{i18n "admin.customize.theme.collapse"}}
                {{else}}
                  {{i18n
                    "admin.customize.theme.and_x_more"
                    count=this.moreCount
                  }}
                {{/if}}
              </a>
            {{/if}}
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
