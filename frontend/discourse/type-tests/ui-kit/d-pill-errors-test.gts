import DPill from "discourse/ui-kit/d-pill";

// Each invocation must be rejected; a missing error fails pnpm lint:types.
const Test = <template>
  {{! @glint-expect-error - @label is required }}
  <DPill @type="info" />

  {{! @glint-expect-error - @label is a string }}
  <DPill @label={{42}} />

  {{! @glint-expect-error - error is not a type; danger is }}
  <DPill @label="Failing" @type="error" />

  {{! @glint-expect-error - @icon is an icon ID, not a flag }}
  <DPill @icon={{true}} @label="Live now" />
</template>;

export default Test;
