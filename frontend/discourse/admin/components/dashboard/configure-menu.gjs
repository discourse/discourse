import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";

export default class ConfigureMenu extends Component {
  sectionLabel = (section) =>
    i18n(`admin.dashboard.sections.${section.id}.title`);

  toggleLabel = (section) =>
    i18n("admin.dashboard.configure.toggle_visibility", {
      label: this.sectionLabel(section),
    });

  /**
   * Forwards a committed move to the controlled owner. The list has already
   * normalized both input paths, suppressed no-ops, and announced, so what
   * remains is the owner's own index-based contract.
   *
   * @param {Object} move - The normalized move.
   */
  @action
  handleMove(move) {
    this.args.onReorder(move.fromIndex, move.toIndex);
  }

  <template>
    <div class="db-configure">
      <DReorderableList
        @items={{@sections}}
        @key="id"
        @label={{this.sectionLabel}}
        @onMove={{this.handleMove}}
        @rowClass="db-configure__row"
        class="db-configure__list"
        aria-label={{i18n "admin.dashboard.configure.menu_title"}}
      >
        <:row as |section|>
          <span class="db-configure__section-name">
            {{this.sectionLabel section}}
          </span>

          <DToggleSwitch
            @state={{section.visible}}
            {{on "click" (fn @onToggleVisibility section.id)}}
            aria-label={{this.toggleLabel section}}
          />
        </:row>
      </DReorderableList>
    </div>
  </template>
}
