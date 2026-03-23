import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import { i18n } from "discourse-i18n";
import {
  loadNodeTypes,
  nodeTypeIcon,
  nodeTypeLabel,
  nodeTypeStyle,
} from "../../../lib/workflows/node-types";

export default class AddNodeButton extends Component {
  @tracked nodeTypes = [];

  constructor() {
    super(...arguments);
    this.#loadTypes();
  }

  async #loadTypes() {
    this.nodeTypes = await loadNodeTypes();
  }

  @action
  selectNodeType(nodeType, closeFn) {
    this.args.onAddNode(
      this.args.sourceClientId,
      this.args.sourceOutput,
      nodeType
    );
    closeFn();
  }

  <template>
    <div class="workflows-add-node-button">
      <DMenu
        @identifier="workflows-add-node"
        @icon="plus"
        @title={{i18n "discourse_workflows.add_node.title"}}
        class="btn-icon-text workflows-add-node-button__trigger"
      >
        <:content as |args|>
          <DropdownMenu as |dropdown|>
            {{#each this.nodeTypes as |nodeType|}}
              <dropdown.item>
                <DButton
                  @action={{fn this.selectNodeType nodeType args.close}}
                  @icon={{nodeTypeIcon nodeType}}
                  @translatedLabel={{nodeTypeLabel nodeType}}
                  class="btn-transparent workflows-add-node-button__item"
                  style={{nodeTypeStyle nodeType}}
                />
              </dropdown.item>
            {{/each}}
          </DropdownMenu>
        </:content>
      </DMenu>
    </div>
  </template>
}
