import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DTabs from "discourse/ui-kit/d-tabs";

export default class TabsHeaderExample extends Component {
  @tracked active = "summary";
  @tracked refreshCount = 0;

  @action
  activate(id) {
    this.active = id;
  }

  @action
  refresh() {
    this.refreshCount += 1;
  }

  <template>
    <div class="styleguide-tabs">
      <DTabs
        @active={{this.active}}
        @label="Report sections"
        @onActivate={{this.activate}}
      >
        <:header as |header|>
          <div class="styleguide-tabs__header">
            <header.Tablist />
            <DButton
              class="btn-small"
              @action={{this.refresh}}
              @icon="arrows-rotate"
              @translatedLabel="Refresh"
            />
          </div>
        </:header>
        <:default as |tabs|>
          <tabs.Tab @id="summary" @label="Summary">
            <p>Refreshed
              {{this.refreshCount}}
              times. The refresh button shares the strip row without being a
              tab, so it stays outside the arrow key cycle and out of the
              tablist's ARIA contents.</p>
          </tabs.Tab>
          <tabs.Tab @id="details" @label="Details">
            <p>The tab buttons still render inside the placed tablist, wherever
              the header block put it.</p>
          </tabs.Tab>
        </:default>
      </DTabs>
    </div>
  </template>
}
