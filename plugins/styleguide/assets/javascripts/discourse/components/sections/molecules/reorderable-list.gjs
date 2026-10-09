import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import ReorderableListBasicExample from "../../examples/molecules/reorderable-list/basic";
import reorderableListBasicSource from "../../examples/molecules/reorderable-list/basic?source=file";
import ReorderableListCreateExample from "../../examples/molecules/reorderable-list/create";
import reorderableListCreateSource from "../../examples/molecules/reorderable-list/create?source=file";
import ReorderableListCrossListExample from "../../examples/molecules/reorderable-list/cross-list";
import reorderableListCrossListSource from "../../examples/molecules/reorderable-list/cross-list?source=file";
import ReorderableListEditableExample from "../../examples/molecules/reorderable-list/editable";
import reorderableListEditableSource from "../../examples/molecules/reorderable-list/editable?source=file";
import ReorderableListPoliciesExample from "../../examples/molecules/reorderable-list/policies";
import reorderableListPoliciesSource from "../../examples/molecules/reorderable-list/policies?source=file";
import ReorderableListTableExample from "../../examples/molecules/reorderable-list/table";
import reorderableListTableSource from "../../examples/molecules/reorderable-list/table?source=file";
import ReorderableListTogglesExample from "../../examples/molecules/reorderable-list/toggles";
import reorderableListTogglesSource from "../../examples/molecules/reorderable-list/toggles?source=file";
import StyleguideGroups from "../../styleguide-groups";

const GROUPS = ["start", "policies", "content", "layouts", "groups"];

export default class ReorderableList extends Component {
  get groups() {
    return GROUPS.map((id) => ({
      id,
      title: i18n(`styleguide.sections.reorderable_list.groups.${id}.title`),
      description: i18n(
        `styleguide.sections.reorderable_list.groups.${id}.description`
      ),
    }));
  }

  <template>
    <p class="section-description">
      {{i18n "styleguide.sections.reorderable_list.description"}}
    </p>

    <StyleguideGroups
      @active={{@group}}
      @ariaLabel={{i18n
        "styleguide.sections.reorderable_list.groups.aria_label"
      }}
      @groups={{this.groups}}
      @section={{@section}}
      as |Group|
    >
      <Group @id="start" as |Example|>
        <Example
          @code={{reorderableListBasicSource}}
          @description={{i18n
            "styleguide.sections.reorderable_list.basic_description"
          }}
          @title={{i18n "styleguide.sections.reorderable_list.basic_example"}}
          @tryThis={{i18n
            "styleguide.sections.reorderable_list.basic_try_this"
          }}
        >
          <ReorderableListBasicExample />
        </Example>
      </Group>

      <Group @id="policies" as |Example|>
        <Example
          @code={{reorderableListPoliciesSource}}
          @description={{i18n
            "styleguide.sections.reorderable_list.policies_description"
          }}
          @title={{i18n
            "styleguide.sections.reorderable_list.policies_example"
          }}
          @tryThis={{i18n
            "styleguide.sections.reorderable_list.policies_try_this"
          }}
        >
          <ReorderableListPoliciesExample />
        </Example>
      </Group>

      <Group @id="content" as |Example|>
        <Example
          @code={{reorderableListTogglesSource}}
          @description={{i18n
            "styleguide.sections.reorderable_list.toggles_description"
          }}
          @title={{i18n "styleguide.sections.reorderable_list.toggles_example"}}
          @tryThis={{i18n
            "styleguide.sections.reorderable_list.toggles_try_this"
          }}
        >
          <ReorderableListTogglesExample />
        </Example>
        <Example
          @code={{reorderableListEditableSource}}
          @description={{i18n
            "styleguide.sections.reorderable_list.editable_description"
          }}
          @title={{i18n
            "styleguide.sections.reorderable_list.editable_example"
          }}
          @tryThis={{i18n
            "styleguide.sections.reorderable_list.editable_try_this"
          }}
        >
          <ReorderableListEditableExample />
        </Example>
        <Example
          @code={{reorderableListCreateSource}}
          @description={{i18n
            "styleguide.sections.reorderable_list.create_description"
          }}
          @title={{i18n "styleguide.sections.reorderable_list.create_example"}}
          @tryThis={{i18n
            "styleguide.sections.reorderable_list.create_try_this"
          }}
        >
          <ReorderableListCreateExample />
        </Example>
      </Group>

      <Group @id="layouts" as |Example|>
        <Example
          @code={{reorderableListTableSource}}
          @description={{i18n
            "styleguide.sections.reorderable_list.table_description"
          }}
          @title={{i18n "styleguide.sections.reorderable_list.table_example"}}
          @tryThis={{i18n
            "styleguide.sections.reorderable_list.table_try_this"
          }}
        >
          <ReorderableListTableExample />
        </Example>
      </Group>

      <Group @id="groups" as |Example|>
        <Example
          @code={{reorderableListCrossListSource}}
          @description={{i18n
            "styleguide.sections.reorderable_list.cross_list_description"
          }}
          @title={{i18n
            "styleguide.sections.reorderable_list.cross_list_example"
          }}
          @tryThis={{i18n
            "styleguide.sections.reorderable_list.cross_list_try_this"
          }}
        >
          <ReorderableListCrossListExample />
        </Example>
      </Group>
    </StyleguideGroups>
  </template>
}
