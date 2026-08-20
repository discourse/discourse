import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import ReorderableListBasicExample from "../../examples/molecules/reorderable-list/basic";
import reorderableListBasicSource from "../../examples/molecules/reorderable-list/basic?source=file";
import ReorderableListButtonsExample from "../../examples/molecules/reorderable-list/buttons";
import reorderableListButtonsSource from "../../examples/molecules/reorderable-list/buttons?source=file";
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
      @groups={{this.groups}}
      @section={{@section}}
      @active={{@group}}
      @ariaLabel={{i18n
        "styleguide.sections.reorderable_list.groups.aria_label"
      }}
      as |Group|
    >
      <Group @id="start" as |Example|>
        <Example
          @title={{i18n "styleguide.sections.reorderable_list.basic_example"}}
          @description={{i18n
            "styleguide.sections.reorderable_list.basic_description"
          }}
          @tryThis={{i18n
            "styleguide.sections.reorderable_list.basic_try_this"
          }}
          @code={{reorderableListBasicSource}}
        >
          <ReorderableListBasicExample />
        </Example>
        <Example
          @title={{i18n "styleguide.sections.reorderable_list.buttons_example"}}
          @description={{i18n
            "styleguide.sections.reorderable_list.buttons_description"
          }}
          @tryThis={{i18n
            "styleguide.sections.reorderable_list.buttons_try_this"
          }}
          @code={{reorderableListButtonsSource}}
        >
          <ReorderableListButtonsExample />
        </Example>
      </Group>

      <Group @id="policies" as |Example|>
        <Example
          @title={{i18n
            "styleguide.sections.reorderable_list.policies_example"
          }}
          @description={{i18n
            "styleguide.sections.reorderable_list.policies_description"
          }}
          @tryThis={{i18n
            "styleguide.sections.reorderable_list.policies_try_this"
          }}
          @code={{reorderableListPoliciesSource}}
        >
          <ReorderableListPoliciesExample />
        </Example>
      </Group>

      <Group @id="content" as |Example|>
        <Example
          @title={{i18n "styleguide.sections.reorderable_list.toggles_example"}}
          @description={{i18n
            "styleguide.sections.reorderable_list.toggles_description"
          }}
          @tryThis={{i18n
            "styleguide.sections.reorderable_list.toggles_try_this"
          }}
          @code={{reorderableListTogglesSource}}
        >
          <ReorderableListTogglesExample />
        </Example>
        <Example
          @title={{i18n
            "styleguide.sections.reorderable_list.editable_example"
          }}
          @description={{i18n
            "styleguide.sections.reorderable_list.editable_description"
          }}
          @tryThis={{i18n
            "styleguide.sections.reorderable_list.editable_try_this"
          }}
          @code={{reorderableListEditableSource}}
        >
          <ReorderableListEditableExample />
        </Example>
        <Example
          @title={{i18n "styleguide.sections.reorderable_list.create_example"}}
          @description={{i18n
            "styleguide.sections.reorderable_list.create_description"
          }}
          @tryThis={{i18n
            "styleguide.sections.reorderable_list.create_try_this"
          }}
          @code={{reorderableListCreateSource}}
        >
          <ReorderableListCreateExample />
        </Example>
      </Group>

      <Group @id="layouts" as |Example|>
        <Example
          @title={{i18n "styleguide.sections.reorderable_list.table_example"}}
          @description={{i18n
            "styleguide.sections.reorderable_list.table_description"
          }}
          @tryThis={{i18n
            "styleguide.sections.reorderable_list.table_try_this"
          }}
          @code={{reorderableListTableSource}}
        >
          <ReorderableListTableExample />
        </Example>
      </Group>

      <Group @id="groups" as |Example|>
        <Example
          @title={{i18n
            "styleguide.sections.reorderable_list.cross_list_example"
          }}
          @description={{i18n
            "styleguide.sections.reorderable_list.cross_list_description"
          }}
          @tryThis={{i18n
            "styleguide.sections.reorderable_list.cross_list_try_this"
          }}
          @code={{reorderableListCrossListSource}}
        >
          <ReorderableListCrossListExample />
        </Example>
      </Group>
    </StyleguideGroups>
  </template>
}
