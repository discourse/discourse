// Negative type assertions for DUserStat's `@value` typing: every invocation below
// must fail to compile. They are quarantined here because a Glint error directive
// suppresses reporting elsewhere in its file, which would let a positive pass
// against a broken declaration. Positives live in d-user-stat-test.gts.
import type { TrustedHTML } from "@ember/template";
import DUserStat from "discourse/ui-kit/d-user-stat";

declare const formatted: string;
declare const markup: TrustedHTML;

const Negatives = <template>
  {{! @glint-expect-error - the default number type takes a number }}
  <DUserStat @label="a" @value={{formatted}} />

  {{! @glint-expect-error - the number type takes a number }}
  <DUserStat @label="a" @type="number" @value={{markup}} />

  {{! @glint-expect-error - the duration type takes a number of seconds }}
  <DUserStat @label="a" @type="duration" @value={{formatted}} />
</template>;

export default Negatives;
