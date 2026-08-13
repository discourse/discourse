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
      @groups={{this.groups}}
      @section={{@section}}
      @active={{@group}}
      @ariaLabel={{i18n "styleguide.sections.roving_focus.groups.aria_label"}}
      as |Group|
    >
      <Group @id="toolbar">
        <StyleguideExample
          @title={{i18n "styleguide.sections.roving_focus.toolbar.example"}}
          @description={{i18n
            "styleguide.sections.roving_focus.toolbar.example_description"
          }}
          @tryThis={{i18n "styleguide.sections.roving_focus.toolbar.try_this"}}
          @code={{rovingFocusToolbarSource}}
        >
          <RovingFocusToolbarExample />
        </StyleguideExample>
      </Group>

      <Group @id="listbox">
        <StyleguideExample
          @title={{i18n "styleguide.sections.roving_focus.multi.example"}}
          @description={{i18n
            "styleguide.sections.roving_focus.multi.example_description"
          }}
          @tryThis={{i18n "styleguide.sections.roving_focus.multi.try_this"}}
          @code={{rovingFocusMultiSelectSource}}
        >
          <RovingFocusMultiSelectExample />
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.roving_focus.listbox.example"}}
          @description={{i18n
            "styleguide.sections.roving_focus.listbox.example_description"
          }}
          @tryThis={{i18n "styleguide.sections.roving_focus.listbox.try_this"}}
          @code={{rovingFocusListboxSource}}
        >
          <RovingFocusListboxExample />
        </StyleguideExample>
      </Group>

      <Group @id="combobox">
        <StyleguideExample
          @title={{i18n "styleguide.sections.roving_focus.combobox.example"}}
          @description={{i18n
            "styleguide.sections.roving_focus.combobox.example_description"
          }}
          @tryThis={{i18n "styleguide.sections.roving_focus.combobox.try_this"}}
          @code={{rovingFocusComboboxSource}}
        >
          <RovingFocusComboboxExample />
        </StyleguideExample>
      </Group>

      <Group @id="radio">
        <StyleguideExample
          @title={{i18n "styleguide.sections.roving_focus.radio.example"}}
          @description={{i18n
            "styleguide.sections.roving_focus.radio.example_description"
          }}
          @tryThis={{i18n "styleguide.sections.roving_focus.radio.try_this"}}
          @code={{rovingFocusRadioGroupSource}}
        >
          <RovingFocusRadioGroupExample />
        </StyleguideExample>
      </Group>

      <Group @id="tree">
        <StyleguideExample
          @title={{i18n "styleguide.sections.roving_focus.tree.example"}}
          @description={{i18n
            "styleguide.sections.roving_focus.tree.example_description"
          }}
          @tryThis={{i18n "styleguide.sections.roving_focus.tree.try_this"}}
          @code={{rovingFocusTreeSource}}
        >
          <RovingFocusTreeExample @dir="ltr" />
        </StyleguideExample>

        <StyleguideExample
          @title={{i18n "styleguide.sections.roving_focus.tree.rtl_example"}}
          @description={{i18n
            "styleguide.sections.roving_focus.tree.rtl_description"
          }}
          @tryThis={{i18n "styleguide.sections.roving_focus.tree.rtl_try_this"}}
        >
          <RovingFocusTreeExample @dir="rtl" />
        </StyleguideExample>
      </Group>

      <Group @id="adjacent">
        <StyleguideExample
          @title={{i18n "styleguide.sections.roving_focus.adjacent.example"}}
          @description={{i18n
            "styleguide.sections.roving_focus.adjacent.example_description"
          }}
          @tryThis={{i18n "styleguide.sections.roving_focus.adjacent.try_this"}}
          @code={{rovingFocusAdjacentGroupsSource}}
        >
          <RovingFocusAdjacentGroupsExample />
        </StyleguideExample>
      </Group>

      <Group @id="components">
        <StyleguideExample
          @title={{i18n "styleguide.sections.roving_focus.tags.example"}}
          @description={{i18n
            "styleguide.sections.roving_focus.tags.example_description"
          }}
          @tryThis={{i18n "styleguide.sections.roving_focus.tags.try_this"}}
          @code={{rovingFocusRemovableTagsSource}}
        >
          <RovingFocusRemovableTagsExample />
        </StyleguideExample>
      </Group>
    </StyleguideGroups>
  </template>
}
