import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import CaretSelectExample from "../../examples/molecules/select/appearance/caret";
import caretSelectSource from "../../examples/molecules/select/appearance/caret?source=file";
import EventsSelectExample from "../../examples/molecules/select/appearance/events";
import eventsSelectSource from "../../examples/molecules/select/appearance/events?source=file";
import FixedIconSelectExample from "../../examples/molecules/select/appearance/fixed-icon";
import fixedIconSelectSource from "../../examples/molecules/select/appearance/fixed-icon?source=file";
import IconOnlySelectExample from "../../examples/molecules/select/appearance/icon-only";
import iconOnlySelectSource from "../../examples/molecules/select/appearance/icon-only?source=file";
import PlacementSelectExample from "../../examples/molecules/select/appearance/placement";
import placementSelectSource from "../../examples/molecules/select/appearance/placement?source=file";
import ValueIconSelectExample from "../../examples/molecules/select/appearance/value-icon";
import valueIconSelectSource from "../../examples/molecules/select/appearance/value-icon?source=file";
import CursorPagedSelectExample from "../../examples/molecules/select/data/cursor-paged";
import cursorPagedSelectSource from "../../examples/molecules/select/data/cursor-paged?source=file";
import DebounceSelectExample from "../../examples/molecules/select/data/debounce";
import debounceSelectSource from "../../examples/molecules/select/data/debounce?source=file";
import MinimumCharactersSelectExample from "../../examples/molecules/select/data/minimum-characters";
import minimumCharactersSelectSource from "../../examples/molecules/select/data/minimum-characters?source=file";
import PagedSelectExample from "../../examples/molecules/select/data/paged";
import pagedSelectSource from "../../examples/molecules/select/data/paged?source=file";
import LargeListSelectExample from "../../examples/molecules/select/limits/large-list";
import largeListSelectSource from "../../examples/molecules/select/limits/large-list?source=file";
import ClearableSelectExample from "../../examples/molecules/select/selection/clearable";
import clearableSelectSource from "../../examples/molecules/select/selection/clearable?source=file";
import ClearableMultipleSelectExample from "../../examples/molecules/select/selection/clearable-multiple";
import clearableMultipleSelectSource from "../../examples/molecules/select/selection/clearable-multiple?source=file";
import DisabledSelectExample from "../../examples/molecules/select/selection/disabled";
import disabledSelectSource from "../../examples/molecules/select/selection/disabled?source=file";
import MaximumSelectExample from "../../examples/molecules/select/selection/maximum";
import maximumSelectSource from "../../examples/molecules/select/selection/maximum?source=file";
import NoneSelectExample from "../../examples/molecules/select/selection/none";
import noneSelectSource from "../../examples/molecules/select/selection/none?source=file";
import ReadonlySelectExample from "../../examples/molecules/select/selection/readonly";
import readonlySelectSource from "../../examples/molecules/select/selection/readonly?source=file";
import ToggleListSelectExample from "../../examples/molecules/select/selection/toggle-list";
import toggleListSelectSource from "../../examples/molecules/select/selection/toggle-list?source=file";
import DefaultSelectExample from "../../examples/molecules/select/start/default";
import defaultSelectSource from "../../examples/molecules/select/start/default?source=file";
import MultipleSelectExample from "../../examples/molecules/select/start/multiple";
import multipleSelectSource from "../../examples/molecules/select/start/multiple?source=file";
import StaticSelectExample from "../../examples/molecules/select/start/static";
import staticSelectSource from "../../examples/molecules/select/start/static?source=file";
import AsyncButtonSelectExample from "../../examples/molecules/select/states/async-button";
import asyncButtonSelectSource from "../../examples/molecules/select/states/async-button?source=file";
import EmptySelectExample from "../../examples/molecules/select/states/empty";
import emptySelectSource from "../../examples/molecules/select/states/empty?source=file";
import ErrorSelectExample from "../../examples/molecules/select/states/error";
import errorSelectSource from "../../examples/molecules/select/states/error?source=file";
import ReloadSelectExample from "../../examples/molecules/select/states/reload";
import reloadSelectSource from "../../examples/molecules/select/states/reload?source=file";
import StyleguideExample from "../../styleguide-example";
import StyleguideGroups from "../../styleguide-groups";
import SelectContent from "./select-content";
import SelectHero from "./select-hero";
import SelectKeyboard from "./select-keyboard";
import SelectShowcases from "./select-showcases";

const GROUPS = [
  "start",
  "data",
  "states",
  "appearance",
  "content",
  "selection",
  "keyboard",
  "limits",
  "pickers",
];

export default class Select extends Component {
  get groups() {
    return GROUPS.map((id) => ({
      id,
      title: i18n(`styleguide.sections.select.groups.${id}.title`),
      description: i18n(`styleguide.sections.select.groups.${id}.description`),
    }));
  }

  <template>
    <p class="section-description">
      {{i18n "styleguide.sections.select.description"}}
    </p>

    <SelectHero />

    <StyleguideGroups
      @groups={{this.groups}}
      @section={{@section}}
      @active={{@group}}
      @ariaLabel={{i18n "styleguide.sections.select.groups.aria_label"}}
      as |Group|
    >
      <Group @id="start">
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.default_example"}}
          @description={{i18n "styleguide.sections.select.default_description"}}
          @tryThis={{i18n "styleguide.sections.select.default_try_this"}}
          @code={{defaultSelectSource}}
        >
          <div class="select-examples__control"><DefaultSelectExample /></div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.static_example"}}
          @description={{i18n "styleguide.sections.select.static_description"}}
          @tryThis={{i18n "styleguide.sections.select.static_try_this"}}
          @code={{staticSelectSource}}
        >
          <div class="select-examples__control"><StaticSelectExample /></div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.multi_example"}}
          @description={{i18n "styleguide.sections.select.multi_description"}}
          @tryThis={{i18n "styleguide.sections.select.multi_try_this"}}
          @code={{multipleSelectSource}}
        >
          <div class="select-examples__control"><MultipleSelectExample /></div>
        </StyleguideExample>
      </Group>

      <Group @id="data">
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.min_chars_example"}}
          @description={{i18n
            "styleguide.sections.select.min_chars_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.min_chars_try_this"}}
          @code={{minimumCharactersSelectSource}}
        >
          <div class="select-examples__control">
            <MinimumCharactersSelectExample />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.debounce_example"}}
          @description={{i18n
            "styleguide.sections.select.debounce_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.debounce_try_this"}}
          @code={{debounceSelectSource}}
        >
          <div class="select-examples__control">
            <DebounceSelectExample />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.paged_example"}}
          @description={{i18n "styleguide.sections.select.paged_description"}}
          @tryThis={{i18n "styleguide.sections.select.paged_try_this"}}
          @code={{pagedSelectSource}}
        >
          <:default>
            <div class="select-examples__control"><PagedSelectExample /></div>
          </:default>
          <:note>{{i18n "styleguide.sections.select.paged_note"}}</:note>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.paged_cursor_example"}}
          @description={{i18n
            "styleguide.sections.select.paged_cursor_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.paged_cursor_try_this"}}
          @code={{cursorPagedSelectSource}}
        >
          <:default>
            <div class="select-examples__control">
              <CursorPagedSelectExample />
            </div>
          </:default>
          <:note>{{i18n "styleguide.sections.select.paged_cursor_note"}}</:note>
        </StyleguideExample>
      </Group>

      <Group @id="states">
        <StyleguideExample
          class="--wide"
          @title={{i18n "styleguide.sections.select.reload_example"}}
          @description={{i18n "styleguide.sections.select.reload_description"}}
          @tryThis={{i18n "styleguide.sections.select.reload_try_this"}}
          @code={{reloadSelectSource}}
        >
          <div class="select-examples__pair">
            <div class="select-examples__pair-item">
              <p class="select-examples__pair-label">
                {{i18n "styleguide.sections.select.reload_fast_label"}}
              </p>
              <ReloadSelectExample @identifier="sg-reload-fast" @speed="fast" />
            </div>
            <div class="select-examples__pair-item">
              <p class="select-examples__pair-label">
                {{i18n "styleguide.sections.select.reload_slow_label"}}
              </p>
              <ReloadSelectExample @identifier="sg-reload-slow" @speed="slow" />
            </div>
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.async_button_example"}}
          @description={{i18n
            "styleguide.sections.select.async_button_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.async_button_try_this"}}
          @code={{asyncButtonSelectSource}}
        >
          <div class="select-examples__control">
            <AsyncButtonSelectExample />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.empty_example"}}
          @description={{i18n "styleguide.sections.select.empty_description"}}
          @tryThis={{i18n "styleguide.sections.select.empty_try_this"}}
          @code={{emptySelectSource}}
        >
          <div class="select-examples__control"><EmptySelectExample /></div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.error_example"}}
          @description={{i18n "styleguide.sections.select.error_description"}}
          @tryThis={{i18n "styleguide.sections.select.error_try_this"}}
          @code={{errorSelectSource}}
        >
          <div class="select-examples__control"><ErrorSelectExample /></div>
        </StyleguideExample>
      </Group>

      <Group @id="appearance">
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.icon_example"}}
          @description={{i18n "styleguide.sections.select.icon_description"}}
          @tryThis={{i18n "styleguide.sections.select.icon_try_this"}}
          @code={{fixedIconSelectSource}}
        >
          <div class="select-examples__control"><FixedIconSelectExample /></div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.icon_follows_example"}}
          @description={{i18n
            "styleguide.sections.select.icon_follows_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.icon_follows_try_this"}}
          @code={{valueIconSelectSource}}
        >
          <div class="select-examples__control"><ValueIconSelectExample /></div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.icon_only_example"}}
          @description={{i18n
            "styleguide.sections.select.icon_only_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.icon_only_try_this"}}
          @code={{iconOnlySelectSource}}
        >
          <div class="select-examples__control"><IconOnlySelectExample /></div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.caret_example"}}
          @description={{i18n "styleguide.sections.select.caret_description"}}
          @tryThis={{i18n "styleguide.sections.select.caret_try_this"}}
          @code={{caretSelectSource}}
        >
          <div class="select-examples__control"><CaretSelectExample /></div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.placement_example"}}
          @description={{i18n
            "styleguide.sections.select.placement_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.placement_try_this"}}
          @code={{placementSelectSource}}
        >
          <div class="select-examples__control"><PlacementSelectExample /></div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.events_example"}}
          @description={{i18n "styleguide.sections.select.events_description"}}
          @tryThis={{i18n "styleguide.sections.select.events_try_this"}}
          @code={{eventsSelectSource}}
        >
          <div class="select-examples__control">
            <EventsSelectExample />
          </div>
        </StyleguideExample>
      </Group>

      <Group @id="content"><SelectContent /></Group>

      <Group @id="selection">
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.maximum_example"}}
          @description={{i18n "styleguide.sections.select.maximum_description"}}
          @tryThis={{i18n "styleguide.sections.select.maximum_try_this"}}
          @code={{maximumSelectSource}}
        >
          <div class="select-examples__control"><MaximumSelectExample /></div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.toggle_example"}}
          @description={{i18n "styleguide.sections.select.toggle_description"}}
          @tryThis={{i18n "styleguide.sections.select.toggle_try_this"}}
          @code={{toggleListSelectSource}}
        >
          <:default>
            <div class="select-examples__control">
              <ToggleListSelectExample />
            </div>
          </:default>
          <:note>{{i18n "styleguide.sections.select.toggle_note"}}</:note>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.none_example"}}
          @description={{i18n "styleguide.sections.select.none_description"}}
          @tryThis={{i18n "styleguide.sections.select.none_try_this"}}
          @code={{noneSelectSource}}
        >
          <div class="select-examples__control"><NoneSelectExample /></div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.clearable_example"}}
          @description={{i18n
            "styleguide.sections.select.clearable_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.clearable_try_this"}}
          @code={{clearableSelectSource}}
        >
          <div class="select-examples__control"><ClearableSelectExample /></div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.clearable_multi_example"}}
          @description={{i18n
            "styleguide.sections.select.clearable_multi_description"
          }}
          @tryThis={{i18n
            "styleguide.sections.select.clearable_multi_try_this"
          }}
          @code={{clearableMultipleSelectSource}}
        >
          <div class="select-examples__control">
            <ClearableMultipleSelectExample />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.disabled_example"}}
          @description={{i18n
            "styleguide.sections.select.disabled_description"
          }}
          @code={{disabledSelectSource}}
        >
          <div class="select-examples__control"><DisabledSelectExample /></div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.readonly_example"}}
          @description={{i18n
            "styleguide.sections.select.readonly_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.readonly_try_this"}}
          @code={{readonlySelectSource}}
        >
          <div class="select-examples__control"><ReadonlySelectExample /></div>
        </StyleguideExample>
      </Group>

      <Group @id="keyboard"><SelectKeyboard /></Group>

      <Group @id="limits">
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.large_list_example"}}
          @description={{i18n
            "styleguide.sections.select.large_list_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.large_list_try_this"}}
          @code={{largeListSelectSource}}
        >
          <:default>
            <div class="select-examples__control">
              <LargeListSelectExample />
            </div>
          </:default>
          <:note>{{i18n "styleguide.sections.select.large_list_note"}}</:note>
        </StyleguideExample>
      </Group>

      <Group @id="pickers"><SelectShowcases /></Group>
    </StyleguideGroups>
  </template>
}
