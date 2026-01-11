import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class InspectorSection extends Component {
  @service routeInspectorState;

  constructor() {
    super(...arguments);
    this.ensureSectionState();
  }

  @action
  ensureSectionState() {
    if (!this.args.sectionKey) {
      return;
    }
    scheduleOnce("afterRender", this, () => {
      this.routeInspectorState.ensureSectionState(
        this.args.sectionKey,
        this.args.defaultCollapsed
      );
    });
  }

  get isCollapsed() {
    return this.args.isCollapsed ?? false;
  }

  get isLong() {
    return this.args.long && !this.isCollapsed;
  }

  <template>
    <div
      class={{concatClass
        "route-inspector__module-section"
        (if this.isLong "--long")
        (if this.isCollapsed "--collapsed")
      }}
      {{didInsert this.ensureSectionState}}
    >
      <div class="route-inspector__table-header" {{on "click" @onToggle}}>
        <div class="route-inspector__table-title-wrapper">
          {{#if @icon}}
            {{icon @icon}}
          {{/if}}
          <h4 class="route-inspector__table-title">{{@label}}</h4>
        </div>
        <button
          type="button"
          class="route-inspector__table-toggle"
          aria-label={{i18n (themePrefix "route_inspector.toggle_details")}}
        >
          {{icon (if this.isCollapsed "angle-up" "angle-down")}}
        </button>
      </div>

      <div class="route-inspector__section-content-wrapper">
        <div class="route-inspector__section-content">
          {{yield}}
        </div>
      </div>
    </div>
  </template>
}
