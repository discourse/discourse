import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DReorderableListGroup from "discourse/ui-kit/d-reorderable-list-group";
import { i18n } from "discourse-i18n";

export default class ReorderableListCrossListExample extends Component {
  primary = trackedArray([
    { id: "home", name: "Home" },
    { id: "latest", name: "Latest" },
    { id: "categories", name: "Categories" },
  ]);

  secondary = trackedArray([
    { id: "badges", name: "Badges" },
    { id: "groups", name: "Groups" },
  ]);

  itemLabel = (item) => item.name;

  @action
  applyMove({ fromList, toList, proposedFromItems, proposedToItems }) {
    const listFor = (id) => (id === "primary" ? this.primary : this.secondary);
    const from = listFor(fromList);
    from.splice(0, from.length, ...proposedFromItems);
    if (toList !== fromList) {
      const to = listFor(toList);
      to.splice(0, to.length, ...proposedToItems);
    }
  }

  <template>
    <DReorderableListGroup @onMove={{this.applyMove}} as |group|>
      <div class="styleguide-reorderable-list-group">
        <div class="styleguide-reorderable-list-group__panel">
          <h4>{{i18n
              "styleguide.sections.reorderable_list.cross_list_primary"
            }}</h4>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @listLabel={{i18n
              "styleguide.sections.reorderable_list.cross_list_primary"
            }}
            @items={{this.primary}}
            @key="id"
            @label={{this.itemLabel}}
            class="styleguide-reorderable-list"
          >
            <:row as |item|>
              <span>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </div>
        <div class="styleguide-reorderable-list-group__panel">
          <h4>{{i18n
              "styleguide.sections.reorderable_list.cross_list_secondary"
            }}</h4>
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @listLabel={{i18n
              "styleguide.sections.reorderable_list.cross_list_secondary"
            }}
            @items={{this.secondary}}
            @key="id"
            @label={{this.itemLabel}}
            class="styleguide-reorderable-list"
          >
            <:row as |item|>
              <span>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </div>
      </div>
    </DReorderableListGroup>
  </template>
}
