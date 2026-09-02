import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DTabs from "discourse/ui-kit/d-tabs";

const SECTIONS = [
  "Overview",
  "Activity",
  "Badges",
  "Notifications",
  "Messages",
  "Invites",
  "Preferences",
  "Security",
];

export default class TabsOverflowExample extends Component {
  @tracked active = SECTIONS[0];

  sections = SECTIONS;

  @action
  activate(id) {
    this.active = id;
  }

  @action
  selectFirst() {
    this.active = SECTIONS[0];
  }

  @action
  selectLast() {
    this.active = SECTIONS[SECTIONS.length - 1];
  }

  <template>
    <div class="styleguide-tabs__controls">
      <DButton
        @action={{this.selectFirst}}
        @translatedLabel="Select the first tab"
      />
      <DButton
        @action={{this.selectLast}}
        @translatedLabel="Select the last tab"
      />
      <span class="styleguide-tabs__status">Active tab: {{this.active}}</span>
    </div>

    <div class="styleguide-tabs styleguide-tabs--narrow">
      <DTabs
        @active={{this.active}}
        @label="Account sections"
        @onActivate={{this.activate}}
        as |tabs|
      >
        {{#each this.sections as |section|}}
          <tabs.Tab @id={{section}} @label={{section}}>
            <p>The
              {{section}}
              tab is selected. The strip scrolled only as far as it needed to
              bring this tab fully into view.</p>
          </tabs.Tab>
        {{/each}}
      </DTabs>
    </div>
  </template>
}
