/**
 * Positive template invocations for DResizeHandles. This file intentionally has
 * no Glint error directives, so a broken public signature cannot be suppressed.
 */
import { array } from "@ember/helper";
import type { TrustedHTML } from "@ember/template";
import DResizeHandles, {
  BOX_DIRECTIONS,
  type BoxDirection,
  type DResizeHandleDragInfo,
} from "discourse/ui-kit/d-resize-handles";

declare const columnHandles: {
  key: string;
  payload: number;
  class?: string;
  style?: TrustedHTML;
}[];
declare const box: Element;
declare function onColumnResize(column: number): void;
declare function onCompassResize(direction: BoxDirection): void;
declare function measureFrom(handle: HTMLElement): Element | null;
declare function veto(direction: BoxDirection): boolean;

/**
 * Reads every field of the report, so the shape of the public callback payload
 * is checked rather than merely its first argument.
 */
function onReport(
  direction: BoxDirection,
  dragInfo: DResizeHandleDragInfo<BoxDirection>
): void {
  const payload: BoxDirection = dragInfo.payload;
  const event: PointerEvent = dragInfo.event;
  const origin: { x: number; y: number } = dragInfo.origin;
  const current: { x: number; y: number } = dragInfo.current;
  const delta: { x: number; y: number } = dragInfo.delta;
  const moved: boolean = dragInfo.moved;
  const session: object = dragInfo.session;
  const measured: Element | null = dragInfo.measured;
  const measuredRect: DOMRect | null = dragInfo.measuredRect;
  void [
    direction,
    payload,
    event,
    origin,
    current,
    delta,
    moved,
    session,
    measured,
    measuredRect,
  ];
}

const Positives = <template>
  {{! The built-in box hands a compass direction to the handler }}
  <DResizeHandles @handleClass="my-block__handle" @threshold={{4}} />
  <DResizeHandles
    @handleClass="my-block__handle"
    @onResize={{onCompassResize}}
  />
  <DResizeHandles
    @handleClass="my-block__handle"
    @directions={{array "n" "s"}}
    @stopPropagation={{true}}
  />

  {{! Explicit descriptors carry the payload type through to the callbacks }}
  <DResizeHandles @handles={{columnHandles}} @onResize={{onColumnResize}} />

  {{! The whole report shape, and the terminal and veto callbacks }}
  <DResizeHandles
    @handleClass="my-block__handle"
    @directions={{BOX_DIRECTIONS}}
    @onResizeStart={{veto}}
    @onResize={{onReport}}
    @onResizeEnd={{onReport}}
    @onResizeCancel={{onReport}}
    @draggingClass="is-dragging"
  />

  {{! cancelCommits belongs with a consumer that handles only the one terminal }}
  <DResizeHandles
    @handleClass="my-block__handle"
    @onResizeEnd={{onReport}}
    @cancelCommits={{true}}
  />

  {{! Both forms of the measure target }}
  <DResizeHandles @handleClass="my-block__handle" @measure={{box}} />
  <DResizeHandles @handleClass="my-block__handle" @measure={{measureFrom}} />
</template>;

export default Positives;
