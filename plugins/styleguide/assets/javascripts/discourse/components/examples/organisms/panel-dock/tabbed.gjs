import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DPanelDock from "discourse/ui-kit/panel-dock";

const Outline = <template>
  <h3 class="styleguide-panel-dock__heading">Outline</h3>
  <ol class="styleguide-panel-dock__list">
    <li>What the panel is for</li>
    <li>Docking it to an edge</li>
    <li>Resizing it</li>
    <li>Remembering the layout</li>
  </ol>
  <p>Each tab keeps its own scroll position, because only the selected panel is
    mounted.</p>
</template>;

const Notes = <template>
  <h3 class="styleguide-panel-dock__heading">Notes</h3>
  <p>The page behind this panel is still live. Click a link, scroll the
    styleguide, open a menu: nothing here traps focus or locks scrolling, which
    is what separates a dock from a modal.</p>
  <p>That is also why the panel has no backdrop. Content you consult while
    working should not dim the work.</p>
</template>;

const History = <template>
  <h3 class="styleguide-panel-dock__heading">History</h3>
  <p>Move the panel with the picker in the header, then reload the page. It
    comes back where you left it, at the width you left it, because the layout
    is stored under the panel's context.</p>
  <p>The last choice in the picker moves the panel into a browser window of its
    own. That is remembered too: reload the page while the panel is out there
    and it is taken back into the same window rather than opening a second one.</p>
</template>;

const TABS = [
  { id: "outline", label: "Outline", component: Outline },
  { id: "notes", label: "Notes", component: Notes },
  { id: "history", label: "History", component: History },
];

export default class PanelDockTabbedExample extends Component {
  @tracked isOpen = false;
  @tracked activeTab = "outline";
  @tracked mode = "docked";

  tabs = TABS;

  @action
  open() {
    this.isOpen = true;
  }

  @action
  close() {
    this.isOpen = false;
  }

  @action
  activate(id) {
    this.activeTab = id;
  }

  @action
  changeMode(mode) {
    this.mode = mode;
  }

  <template>
    <div class="styleguide-panel-dock styleguide-panel-dock--tabbed">
      <div class="styleguide-panel-dock__controls">
        <DButton
          class="styleguide-panel-dock__open"
          @action={{this.open}}
          @disabled={{this.isOpen}}
          @translatedLabel="Open the dock"
        />
        <span class="styleguide-panel-dock__status">Active tab:
          {{this.activeTab}}</span>
        <span class="styleguide-panel-dock__status">Placement:
          {{this.mode}}</span>
      </div>

      <DPanelDock
        @context="styleguide-tabbed-dock"
        @isOpen={{this.isOpen}}
        @tabs={{this.tabs}}
        @activeTab={{this.activeTab}}
        @onActivateTab={{this.activate}}
        @onClose={{this.close}}
        @dockable={{true}}
        @windowable={{true}}
        @onModeChange={{this.changeMode}}
        @defaultSide="end"
      />
    </div>
  </template>
}
