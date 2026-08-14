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

const Positives = <template>
  {{! A separator takes numbers or measurement functions for its size }}
  <DResizeSeparator
    @axis="vertical"
    @side="end"
    @value={{size}}
    @min={{size}}
    @max={{size}}
    @label="Resize"
    @observe={{box}}
    @onResizeStart={{noop}}
    class="my-block__handle"
  />
  <DResizeSeparator
    @axis="horizontal"
    @value={{measure}}
    @min={{measure}}
    @max={{measure}}
    @label="Resize"
  >grip</DResizeSeparator>
  {{! A measured SIZE may honestly say "not yet": null withholds aria-valuenow.
    Bounds may not, so they stay non-nullable here. }}
  <DResizeSeparator
    @axis="horizontal"
    @value={{measureMaybe}}
    @min={{size}}
    @max={{measure}}
    @label="Resize"
  />
</template>;

export default Positives;
