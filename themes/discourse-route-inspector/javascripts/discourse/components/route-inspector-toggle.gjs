import Component from "@glimmer/component";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class RouteInspectorToggle extends Component {
  @service routeInspectorState;

  get isActive() {
    return this.routeInspectorState.isVisible;
  }

  @action
  toggle(event) {
    event.preventDefault();
    this.routeInspectorState.toggleVisibility();
    event.currentTarget.blur();
  }

  <template>
    <li class="header-dropdown-toggle route-inspector-toggle">
      <button
        type="button"
        class="icon btn-flat no-text"
        title={{i18n (themePrefix "route_inspector.toggle_button")}}
        aria-label={{i18n (themePrefix "route_inspector.toggle_button")}}
        aria-pressed={{if this.isActive "true" "false"}}
        {{on "click" this.toggle}}
      >
        {{icon "lucide-map-pin"}}
      </button>
    </li>
  </template>
}
