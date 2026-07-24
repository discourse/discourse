import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

export default class QueryRunSplitButton extends Component {
  @action
  runPlain() {
    this.args.onRun?.(false);
  }

  @action
  runWithExplain(dMenu) {
    this.args.onRun?.(true);
    dMenu?.close();
  }

  <template>
    <div class="query-run-split">
      <DButton
        @action={{this.runPlain}}
        @icon="play"
        @label={{or @label "explorer.run"}}
        @disabled={{@disabled}}
        class="btn-primary query-run-split__primary"
      />
      <DMenu
        @identifier="query-run-options"
        @icon="angle-down"
        @ariaLabel={{i18n "explorer.run_options"}}
        @triggerClass="btn-primary query-run-split__chevron"
        @placement="bottom-end"
        @disabled={{@disabled}}
      >
        <:content as |dMenu|>
          <DDropdownMenu as |dropdown|>
            <dropdown.item>
              <DButton
                @action={{fn this.runWithExplain dMenu}}
                @icon="list-ul"
                @label="explorer.run_with_explain"
                class="btn-transparent query-run-split__with-explain"
              />
            </dropdown.item>
          </DDropdownMenu>
        </:content>
      </DMenu>
    </div>
  </template>
}
