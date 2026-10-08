// Negative type assertions for DResizeSeparator: every invocation below must
// fail to compile. They are quarantined here because a Glint error directive
// suppresses reporting elsewhere in its file, which would let a positive
// assertion pass against a broken declaration. Positives live in
// d-resize-separator-test.gts.
import DResizeSeparator from "discourse/ui-kit/d-resize-separator";

declare const px: number;

const Negatives = <template>
  {{! @glint-expect-error - a focusable separator with no accessible name is announced as a bare splitter, so the label is required }}
  <DResizeSeparator @max={{px}} @min={{px}} @value={{px}} />

  <DResizeSeparator
    {{! @glint-expect-error - a separator resizes along one of two axes }}
    @axis="diagonal"
    @label="Resize"
    @max={{px}}
    @min={{px}}
    @value={{px}}
  />

  <DResizeSeparator
    @label="Resize"
    {{! @glint-expect-error - the box is an element or a function returning one }}
    @measure={{px}}
  />
</template>;

export default Negatives;
