import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import AxisExample from "../../examples/molecules/drag-and-drop/basics/axis";
import axisSource from "../../examples/molecules/drag-and-drop/basics/axis?source=file";
import FixedPositionExample from "../../examples/molecules/drag-and-drop/basics/fixed-position";
import fixedpositionSource from "../../examples/molecules/drag-and-drop/basics/fixed-position?source=file";
import PositionsExample from "../../examples/molecules/drag-and-drop/basics/positions";
import positionsSource from "../../examples/molecules/drag-and-drop/basics/positions?source=file";
import TypesExample from "../../examples/molecules/drag-and-drop/basics/types";
import typesSource from "../../examples/molecules/drag-and-drop/basics/types?source=file";
import PointerDragExample from "../../examples/molecules/drag-and-drop/gestures/pointer-drag";
import pointerdragSource from "../../examples/molecules/drag-and-drop/gestures/pointer-drag?source=file";
import SwipeExample from "../../examples/molecules/drag-and-drop/gestures/swipe";
import swipeSource from "../../examples/molecules/drag-and-drop/gestures/swipe?source=file";
import AdoptionExample from "../../examples/molecules/drag-and-drop/outside/adoption";
import adoptionSource from "../../examples/molecules/drag-and-drop/outside/adoption?source=file";
import ExternalExample from "../../examples/molecules/drag-and-drop/outside/external";
import externalSource from "../../examples/molecules/drag-and-drop/outside/external?source=file";
import ExternalAxisExample from "../../examples/molecules/drag-and-drop/outside/external-axis";
import externalaxisSource from "../../examples/molecules/drag-and-drop/outside/external-axis?source=file";
import AutoScrollExample from "../../examples/molecules/drag-and-drop/reacting/auto-scroll";
import autoscrollSource from "../../examples/molecules/drag-and-drop/reacting/auto-scroll?source=file";
import DwellExample from "../../examples/molecules/drag-and-drop/reacting/dwell";
import dwellSource from "../../examples/molecules/drag-and-drop/reacting/dwell?source=file";
import MonitorExample from "../../examples/molecules/drag-and-drop/reacting/monitor";
import monitorSource from "../../examples/molecules/drag-and-drop/reacting/monitor?source=file";
import ServiceExample from "../../examples/molecules/drag-and-drop/reacting/service";
import serviceSource from "../../examples/molecules/drag-and-drop/reacting/service?source=file";
import EdgeExample from "../../examples/molecules/drag-and-drop/resize/edge";
import edgeSource from "../../examples/molecules/drag-and-drop/resize/edge?source=file";
import HandlesExample from "../../examples/molecules/drag-and-drop/resize/handles";
import handlesSource from "../../examples/molecules/drag-and-drop/resize/handles?source=file";
import SeparatorExample from "../../examples/molecules/drag-and-drop/resize/separator";
import separatorSource from "../../examples/molecules/drag-and-drop/resize/separator?source=file";
import DisabledExample from "../../examples/molecules/drag-and-drop/sources/disabled";
import disabledSource from "../../examples/molecules/drag-and-drop/sources/disabled?source=file";
import EffectExample from "../../examples/molecules/drag-and-drop/sources/effect";
import effectSource from "../../examples/molecules/drag-and-drop/sources/effect?source=file";
import HandleExample from "../../examples/molecules/drag-and-drop/sources/handle";
import handleSource from "../../examples/molecules/drag-and-drop/sources/handle?source=file";
import PreviewExample from "../../examples/molecules/drag-and-drop/sources/preview";
import previewSource from "../../examples/molecules/drag-and-drop/sources/preview?source=file";
import AcceptsSelfExample from "../../examples/molecules/drag-and-drop/targets/accepts-self";
import acceptsselfSource from "../../examples/molecules/drag-and-drop/targets/accepts-self?source=file";
import CanDropExample from "../../examples/molecules/drag-and-drop/targets/can-drop";
import candropSource from "../../examples/molecules/drag-and-drop/targets/can-drop?source=file";
import NestingExample from "../../examples/molecules/drag-and-drop/targets/nesting";
import nestingSource from "../../examples/molecules/drag-and-drop/targets/nesting?source=file";
import StyleguideGroups from "../../styleguide-groups";

const GROUPS = [
  "basics",
  "sources",
  "targets",
  "outside",
  "reacting",
  "resize",
  "gestures",
];

export default class DragAndDrop extends Component {
  get groups() {
    return GROUPS.map((id) => ({
      id,
      title: i18n(`styleguide.sections.drag_and_drop.groups.${id}.title`),
      description: i18n(
        `styleguide.sections.drag_and_drop.groups.${id}.description`
      ),
    }));
  }

  <template>
    <p class="section-description">
      {{i18n "styleguide.sections.drag_and_drop.description"}}
    </p>

    <StyleguideGroups
      @active={{@group}}
      @ariaLabel={{i18n "styleguide.sections.drag_and_drop.groups.aria_label"}}
      @groups={{this.groups}}
      @section={{@section}}
      as |Group|
    >
      <Group @id="basics" as |Example|>
        <Example
          @code={{typesSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.types_description"
          }}
          @kind="modifier"
          @note={{i18n "styleguide.sections.drag_and_drop.types_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.types_title"}}
          @tryThis={{i18n "styleguide.sections.drag_and_drop.types_try_this"}}
        >
          <TypesExample />
        </Example>
        <Example
          @code={{positionsSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.positions_description"
          }}
          @kind="modifier"
          @note={{i18n "styleguide.sections.drag_and_drop.positions_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.positions_title"}}
        >
          <PositionsExample />
        </Example>
        <Example
          @code={{axisSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.axis_description"
          }}
          @kind="modifier"
          @title={{i18n "styleguide.sections.drag_and_drop.axis_title"}}
          @tryThis={{i18n "styleguide.sections.drag_and_drop.axis_try_this"}}
        >
          <AxisExample />
        </Example>
        <Example
          @code={{fixedpositionSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.fixed_position_description"
          }}
          @kind="modifier"
          @title={{i18n
            "styleguide.sections.drag_and_drop.fixed_position_title"
          }}
          @tryThis={{i18n
            "styleguide.sections.drag_and_drop.fixed_position_try_this"
          }}
        >
          <FixedPositionExample />
        </Example>
      </Group>

      <Group @id="sources" as |Example|>
        <Example
          @code={{handleSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.handle_description"
          }}
          @kind="modifier"
          @note={{i18n "styleguide.sections.drag_and_drop.handle_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.handle_title"}}
          @tryThis={{i18n "styleguide.sections.drag_and_drop.handle_try_this"}}
        >
          <HandleExample />
        </Example>
        <Example
          @code={{previewSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.preview_description"
          }}
          @kind="modifier"
          @title={{i18n "styleguide.sections.drag_and_drop.preview_title"}}
          @tryThis={{i18n "styleguide.sections.drag_and_drop.preview_try_this"}}
        >
          <PreviewExample />
        </Example>
        <Example
          @code={{disabledSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.disabled_description"
          }}
          @kind="modifier"
          @title={{i18n "styleguide.sections.drag_and_drop.disabled_title"}}
          @tryThis={{i18n
            "styleguide.sections.drag_and_drop.disabled_try_this"
          }}
        >
          <DisabledExample />
        </Example>
        <Example
          @code={{effectSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.effect_description"
          }}
          @kind="modifier"
          @note={{i18n "styleguide.sections.drag_and_drop.effect_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.effect_title"}}
          @tryThis={{i18n "styleguide.sections.drag_and_drop.effect_try_this"}}
        >
          <EffectExample />
        </Example>
      </Group>

      <Group @id="targets" as |Example|>
        <Example
          @code={{nestingSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.nesting_description"
          }}
          @kind="modifier"
          @note={{i18n "styleguide.sections.drag_and_drop.nesting_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.nesting_title"}}
          @tryThis={{i18n "styleguide.sections.drag_and_drop.nesting_try_this"}}
        >
          <NestingExample />
        </Example>
        <Example
          @code={{acceptsselfSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.accepts_self_description"
          }}
          @kind="modifier"
          @note={{i18n "styleguide.sections.drag_and_drop.accepts_self_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.accepts_self_title"}}
          @tryThis={{i18n
            "styleguide.sections.drag_and_drop.accepts_self_try_this"
          }}
        >
          <AcceptsSelfExample />
        </Example>
        <Example
          @code={{candropSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.can_drop_description"
          }}
          @kind="modifier"
          @title={{i18n "styleguide.sections.drag_and_drop.can_drop_title"}}
          @tryThis={{i18n
            "styleguide.sections.drag_and_drop.can_drop_try_this"
          }}
        >
          <CanDropExample />
        </Example>
      </Group>

      <Group @id="outside" as |Example|>
        <Example
          @code={{adoptionSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.adoption_description"
          }}
          @kind="modifier"
          @note={{i18n "styleguide.sections.drag_and_drop.adoption_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.adoption_title"}}
          @tryThis={{i18n
            "styleguide.sections.drag_and_drop.adoption_try_this"
          }}
        >
          <AdoptionExample />
        </Example>
        <Example
          @code={{externalSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.external_description"
          }}
          @kind="modifier"
          @note={{i18n "styleguide.sections.drag_and_drop.external_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.external_title"}}
          @tryThis={{i18n
            "styleguide.sections.drag_and_drop.external_try_this"
          }}
        >
          <ExternalExample />
        </Example>
        <Example
          @code={{externalaxisSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.external_axis_description"
          }}
          @kind="modifier"
          @note={{i18n "styleguide.sections.drag_and_drop.external_axis_note"}}
          @title={{i18n
            "styleguide.sections.drag_and_drop.external_axis_title"
          }}
          @tryThis={{i18n
            "styleguide.sections.drag_and_drop.external_axis_try_this"
          }}
        >
          <ExternalAxisExample />
        </Example>
      </Group>

      <Group @id="reacting" as |Example|>
        <Example
          @code={{monitorSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.monitor_description"
          }}
          @kind="modifier"
          @note={{i18n "styleguide.sections.drag_and_drop.monitor_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.monitor_title"}}
          @tryThis={{i18n "styleguide.sections.drag_and_drop.monitor_try_this"}}
        >
          <MonitorExample />
        </Example>
        <Example
          @code={{serviceSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.service_description"
          }}
          @kind="service"
          @note={{i18n "styleguide.sections.drag_and_drop.service_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.service_title"}}
          @tryThis={{i18n "styleguide.sections.drag_and_drop.service_try_this"}}
        >
          <ServiceExample />
        </Example>
        <Example
          @code={{autoscrollSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.auto_scroll_description"
          }}
          @kind="modifier"
          @title={{i18n "styleguide.sections.drag_and_drop.auto_scroll_title"}}
          @tryThis={{i18n
            "styleguide.sections.drag_and_drop.auto_scroll_try_this"
          }}
        >
          <AutoScrollExample />
        </Example>

        <Example
          @code={{dwellSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.dwell_description"
          }}
          @kind="modifier"
          @note={{i18n "styleguide.sections.drag_and_drop.dwell_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.dwell_title"}}
          @tryThis={{i18n "styleguide.sections.drag_and_drop.dwell_try_this"}}
        >
          <DwellExample />
        </Example>
      </Group>

      <Group @id="resize" as |Example|>
        <Example
          @code={{separatorSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.separator_description"
          }}
          @kind="component"
          @note={{i18n "styleguide.sections.drag_and_drop.separator_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.separator_title"}}
          @tryThis={{i18n
            "styleguide.sections.drag_and_drop.separator_try_this"
          }}
        >
          <SeparatorExample />
        </Example>
        <Example
          @code={{edgeSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.edge_description"
          }}
          @kind="modifier"
          @note={{i18n "styleguide.sections.drag_and_drop.edge_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.edge_title"}}
          @tryThis={{i18n "styleguide.sections.drag_and_drop.edge_try_this"}}
        >
          <EdgeExample />
        </Example>
        <Example
          @code={{handlesSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.handles_description"
          }}
          @kind="component"
          @note={{i18n "styleguide.sections.drag_and_drop.handles_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.handles_title"}}
          @tryThis={{i18n "styleguide.sections.drag_and_drop.handles_try_this"}}
        >
          <HandlesExample />
        </Example>
      </Group>

      <Group @id="gestures" as |Example|>
        <Example
          @code={{pointerdragSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.pointer_drag_description"
          }}
          @kind="modifier"
          @note={{i18n "styleguide.sections.drag_and_drop.pointer_drag_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.pointer_drag_title"}}
          @tryThis={{i18n
            "styleguide.sections.drag_and_drop.pointer_drag_try_this"
          }}
        >
          <PointerDragExample />
        </Example>
        <Example
          @code={{swipeSource}}
          @description={{i18n
            "styleguide.sections.drag_and_drop.swipe_description"
          }}
          @kind="modifier"
          @note={{i18n "styleguide.sections.drag_and_drop.swipe_note"}}
          @title={{i18n "styleguide.sections.drag_and_drop.swipe_title"}}
          @tryThis={{i18n "styleguide.sections.drag_and_drop.swipe_try_this"}}
        >
          <SwipeExample />
        </Example>
      </Group>
    </StyleguideGroups>
  </template>
}
