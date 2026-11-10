// Positive template invocations for DResizeSeparator. Keep this file free of
// Glint directives: a single `@glint-expect-error` anywhere makes Glint stop
// reporting every other error in the file, so a broken declaration would pass
// unnoticed. Negatives live in d-resize-separator-errors-test.gts.
import DResizeSeparator from "discourse/ui-kit/d-resize-separator";

declare const noop: () => void;
declare const size: number;
declare const measure: () => number;
declare const measureMaybe: () => number | null;
declare const box: HTMLElement;
declare function resolveBox(separator: HTMLElement): HTMLElement | null;

const Positives = <template>
  {{! The ordinary case: the box alone, in either form }}
  <DResizeSeparator @label="Resize" @measure={{box}} />
  <DResizeSeparator
    @axis="horizontal"
    @label="Resize"
    @measure={{resolveBox}}
    @onResizeStart={{noop}}
  />

  {{! Sizes may still be supplied, and may be given alongside the box }}
  <DResizeSeparator
    class="my-block__handle"
    @axis="vertical"
    @label="Resize"
    @max={{size}}
    @measure={{box}}
    @min={{size}}
    @onResizeStart={{noop}}
    @side="end"
    @value={{size}}
  />
  <DResizeSeparator
    @axis="horizontal"
    @label="Resize"
    @max={{measure}}
    @min={{measure}}
    @value={{measure}}
  >grip</DResizeSeparator>
  {{! A measured SIZE may honestly say "not yet": null withholds aria-valuenow.
    Bounds may not, so they stay non-nullable here. }}
  <DResizeSeparator
    @axis="horizontal"
    @label="Resize"
    @max={{measure}}
    @min={{size}}
    @value={{measureMaybe}}
  />
</template>;

export default Positives;
