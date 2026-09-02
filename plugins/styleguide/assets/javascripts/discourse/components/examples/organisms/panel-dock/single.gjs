import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DPanelDock from "discourse/ui-kit/panel-dock";

const Reference = <template>
  <h3 class="styleguide-panel-dock__heading">Reference</h3>
  <p>One panel is not a choice, so there is no strip to choose from. The header
    row stays for the close button, and the panel takes the rest.</p>
  <p>Give the same panel a second tab and the strip appears on its own.</p>
</template>;

const TABS = [{ id: "reference", label: "Reference", component: Reference }];

export default class PanelDockSingleExample extends Component {
  @tracked isOpen = false;

  tabs = TABS;

  @action
  open() {
    this.isOpen = true;
  }

  @action
  close() {
    this.isOpen = false;
  }

  <template>
    <div class="styleguide-panel-dock styleguide-panel-dock--single">
      <div class="styleguide-panel-dock__controls">
        <DButton
          class="styleguide-panel-dock__open"
          @action={{this.open}}
          @disabled={{this.isOpen}}
          @translatedLabel="Open the dock"
        />
      </div>

      <DPanelDock
        @context="styleguide-single-panel"
        @isOpen={{this.isOpen}}
        @tabs={{this.tabs}}
        @onClose={{this.close}}
        @defaultSide="start"
      />
    </div>
  </template>
}
