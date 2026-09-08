import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DTabs from "discourse/ui-kit/d-tabs";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class TabsBasicExample extends Component {
  @tracked active = "overview";

  @action
  activate(id) {
    this.active = id;
  }

  @action
  selectBadges() {
    this.active = "badges";
  }

  <template>
    <div class="styleguide-tabs__controls">
      <DButton
        @action={{this.selectBadges}}
        @translatedLabel="Select the badges tab from outside"
      />
      <span class="styleguide-tabs__status">Active tab: {{this.active}}</span>
    </div>

    <div class="styleguide-tabs">
      <DTabs
        @active={{this.active}}
        @label="Profile sections"
        @onActivate={{this.activate}}
        as |tabs|
      >
        <tabs.Tab @id="overview" @label="Overview">
          <p>The panel keeps one element for the whole group. Switching tabs
            swaps its content in place, so its id and role never change hands.</p>
        </tabs.Tab>
        <tabs.Tab @id="activity" @label="Activity">
          <p>Nothing here moved until the owner fed the id back through the
            active argument. The widget holds no selection of its own.</p>
        </tabs.Tab>
        <tabs.Tab @id="badges">
          <:label>{{dIcon "certificate"}} Badges</:label>
          <:default>
            <p>A label block accepts arbitrary content, such as an icon beside
              the text.</p>
          </:default>
        </tabs.Tab>
        <tabs.Tab @id="admin" @label="Admin" @disabled={{true}}>
          <p>This content never shows: a disabled tab is focusable but inert.</p>
        </tabs.Tab>
      </DTabs>
    </div>
  </template>
}
