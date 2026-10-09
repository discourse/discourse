import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import RovingFocusAdjacentGroupsExample from "../../examples/molecules/roving-focus/adjacent-groups";
import rovingFocusAdjacentGroupsSource from "../../examples/molecules/roving-focus/adjacent-groups?source=file";
import RovingFocusComboboxExample from "../../examples/molecules/roving-focus/combobox";
import rovingFocusComboboxSource from "../../examples/molecules/roving-focus/combobox?source=file";
import RovingFocusListboxExample from "../../examples/molecules/roving-focus/listbox";
import rovingFocusListboxSource from "../../examples/molecules/roving-focus/listbox?source=file";
import RovingFocusMultiSelectExample from "../../examples/molecules/roving-focus/multi-select";
import rovingFocusMultiSelectSource from "../../examples/molecules/roving-focus/multi-select?source=file";
import RovingFocusRadioGroupExample from "../../examples/molecules/roving-focus/radio-group";
import rovingFocusRadioGroupSource from "../../examples/molecules/roving-focus/radio-group?source=file";
import RovingFocusRemovableTagsExample from "../../examples/molecules/roving-focus/removable-tags";
import rovingFocusRemovableTagsSource from "../../examples/molecules/roving-focus/removable-tags?source=file";
import RovingFocusToolbarExample from "../../examples/molecules/roving-focus/toolbar";
import rovingFocusToolbarSource from "../../examples/molecules/roving-focus/toolbar?source=file";
import RovingFocusTreeExample from "../../examples/molecules/roving-focus/tree";
import rovingFocusTreeSource from "../../examples/molecules/roving-focus/tree?source=file";
import StyleguideExample from "../../styleguide-example";
import StyleguideGroups from "../../styleguide-groups";

const GROUPS = [
  "toolbar",
  "listbox",
  "combobox",
  "radio",
  "tree",
  "adjacent",
  "components",
];

/**
 * Conformance demos for the roving-focus modifier, mirroring the interactive examples in the
 * WAI-ARIA Authoring Practices at
 * https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
 *
 * Deliberately plain semantic HTML rather than shared components. A failure here is
 * unambiguously the modifier's, which is the point of this tier; the same patterns built from
 * real components belong beside it later, where the interesting failures actually live.
 */
export default class RovingFocus extends Component {
  get groups() {
    return GROUPS.map((id) => ({
      id,
      title: i18n(`styleguide.sections.roving_focus.groups.${id}.title`),
      description: i18n(
        `styleguide.sections.roving_focus.groups.${id}.description`
      ),
    }));
  }

  <template>
    <p class="section-description">
      {{i18n "styleguide.sections.roving_focus.description"}}
    </p>

    <StyleguideGroups
      @active={{@group}}
      @ariaLabel={{i18n "styleguide.sections.roving_focus.groups.aria_label"}}
      @groups={{this.groups}}
      @section={{@section}}
      as |Group|
    >
      <Group @id="toolbar">
        <StyleguideExample
          @code={{rovingFocusToolbarSource}}
          @description={{i18n
            "styleguide.sections.roving_focus.toolbar.example_description"
          }}
          @title={{i18n "styleguide.sections.roving_focus.toolbar.example"}}
          @tryThis={{i18n "styleguide.sections.roving_focus.toolbar.try_this"}}
        >
          <RovingFocusToolbarExample />
        </StyleguideExample>
      </Group>

      <Group @id="listbox">
        <StyleguideExample
          @code={{rovingFocusMultiSelectSource}}
          @description={{i18n
            "styleguide.sections.roving_focus.multi.example_description"
          }}
          @title={{i18n "styleguide.sections.roving_focus.multi.example"}}
          @tryThis={{i18n "styleguide.sections.roving_focus.multi.try_this"}}
        >
          <RovingFocusMultiSelectExample />
        </StyleguideExample>
        <StyleguideExample
          @code={{rovingFocusListboxSource}}
          @description={{i18n
            "styleguide.sections.roving_focus.listbox.example_description"
          }}
          @title={{i18n "styleguide.sections.roving_focus.listbox.example"}}
          @tryThis={{i18n "styleguide.sections.roving_focus.listbox.try_this"}}
        >
          <RovingFocusListboxExample />
        </StyleguideExample>
      </Group>

      <Group @id="combobox">
        <StyleguideExample
          @code={{rovingFocusComboboxSource}}
          @description={{i18n
            "styleguide.sections.roving_focus.combobox.example_description"
          }}
          @title={{i18n "styleguide.sections.roving_focus.combobox.example"}}
          @tryThis={{i18n "styleguide.sections.roving_focus.combobox.try_this"}}
        >
          <RovingFocusComboboxExample />
        </StyleguideExample>
      </Group>

      <Group @id="radio">
        <StyleguideExample
          @code={{rovingFocusRadioGroupSource}}
          @description={{i18n
            "styleguide.sections.roving_focus.radio.example_description"
          }}
          @title={{i18n "styleguide.sections.roving_focus.radio.example"}}
          @tryThis={{i18n "styleguide.sections.roving_focus.radio.try_this"}}
        >
          <RovingFocusRadioGroupExample />
        </StyleguideExample>
      </Group>

      <Group @id="tree">
        <StyleguideExample
          @code={{rovingFocusTreeSource}}
          @description={{i18n
            "styleguide.sections.roving_focus.tree.example_description"
          }}
          @title={{i18n "styleguide.sections.roving_focus.tree.example"}}
          @tryThis={{i18n "styleguide.sections.roving_focus.tree.try_this"}}
        >
          <RovingFocusTreeExample @dir="ltr" />
        </StyleguideExample>

        <StyleguideExample
          @description={{i18n
            "styleguide.sections.roving_focus.tree.rtl_description"
          }}
          @title={{i18n "styleguide.sections.roving_focus.tree.rtl_example"}}
          @tryThis={{i18n "styleguide.sections.roving_focus.tree.rtl_try_this"}}
        >
          <RovingFocusTreeExample @dir="rtl" />
        </StyleguideExample>
      </Group>

      <Group @id="adjacent">
        <StyleguideExample
          @code={{rovingFocusAdjacentGroupsSource}}
          @description={{i18n
            "styleguide.sections.roving_focus.adjacent.example_description"
          }}
          @title={{i18n "styleguide.sections.roving_focus.adjacent.example"}}
          @tryThis={{i18n "styleguide.sections.roving_focus.adjacent.try_this"}}
        >
          <RovingFocusAdjacentGroupsExample />
        </StyleguideExample>
      </Group>

      <Group @id="components">
        <StyleguideExample
          @code={{rovingFocusRemovableTagsSource}}
          @description={{i18n
            "styleguide.sections.roving_focus.tags.example_description"
          }}
          @title={{i18n "styleguide.sections.roving_focus.tags.example"}}
          @tryThis={{i18n "styleguide.sections.roving_focus.tags.try_this"}}
        >
          <RovingFocusRemovableTagsExample />
        </StyleguideExample>
      </Group>
    </StyleguideGroups>
  </template>
}
