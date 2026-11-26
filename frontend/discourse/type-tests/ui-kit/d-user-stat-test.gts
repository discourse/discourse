// Positive type assertions for DUserStat's `@value` typing: every invocation below
// must compile. Keep this file free of Glint error directives, because one would
// suppress reporting for the rest of the file. Negatives live in
// d-user-stat-errors-test.gts.
import type { TrustedHTML } from "@ember/template";
import DUserStat from "discourse/ui-kit/d-user-stat";

declare const count: number;
declare const formatted: string;
declare const markup: TrustedHTML;

const Positives = <template>
  {{! The number and duration types take a number }}
  <DUserStat @label="a" @value={{count}} />
  <DUserStat @label="a" @type="number" @value={{count}} />
  <DUserStat @label="a" @type="duration" @value={{count}} />

  {{! The string type shows any displayable value as given }}
  <DUserStat @label="a" @type="string" @value={{formatted}} />
  <DUserStat @label="a" @type="string" @value={{markup}} />
  <DUserStat @label="a" @type="string" @value={{null}} />
  <DUserStat @label="a" @type="string" @value={{count}} />

  {{! The value may be left out }}
  <DUserStat @label="a" />
</template>;

export default Positives;
