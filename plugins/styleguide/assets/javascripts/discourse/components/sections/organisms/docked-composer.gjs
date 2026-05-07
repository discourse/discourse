import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DockedComposer from "discourse/components/docked-composer";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import Controls from "discourse/plugins/styleguide/discourse/components/styleguide/controls";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class DockedComposerSection extends Component {
  @tracked resizable = true;
  @tracked disabled = false;
  @tracked placeholder = i18n("composer.reply_placeholder");
  submitTitle = "composer.title";

  @action
  toggleResizable() {
    this.resizable = !this.resizable;
  }

  @action
  toggleDisabled() {
    this.disabled = !this.disabled;
  }

  @action
  async handleSubmit({ raw }) {
    // no-op: pretend the submission succeeded so the composer clears itself
    // eslint-disable-next-line no-console
    console.log("[styleguide] DockedComposer submit:", raw);
    return { ok: true };
  }

  <template>
    {{! template-lint-disable no-potential-path-strings}}
    <StyleguideExample @title="<DockedComposer>">
      <StyleguideComponent>
        <div class="docked-composer-styleguide">
          <DockedComposer
            @resizable={{this.resizable}}
            @disabled={{this.disabled}}
            @placeholder={{this.placeholder}}
            @submitTitle={{this.submitTitle}}
            @uploadTitle="composer.upload_title"
            @draftKey="styleguide-docked-composer"
            @uploaderId="styleguide-docked-composer-uploader"
            @onSubmit={{this.handleSubmit}}
          />
        </div>
      </StyleguideComponent>

      <Controls>
        <Row @name="@resizable">
          <DToggleSwitch
            @state={{this.resizable}}
            {{on "click" this.toggleResizable}}
          />
        </Row>
        <Row @name="@disabled">
          <DToggleSwitch
            @state={{this.disabled}}
            {{on "click" this.toggleDisabled}}
          />
        </Row>
        <Row @name="@placeholder">
          <input
            {{on "input" (withEventValue (fn (mut this.placeholder)))}}
            type="text"
            value={{this.placeholder}}
          />
        </Row>
      </Controls>
    </StyleguideExample>
  </template>
}
