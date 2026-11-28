import DPill from "discourse/ui-kit/d-pill";

declare const label: string;
declare const live: boolean;

// Keep this file free of glint-expect-error: one anywhere hides every other error in the file.
const Test = <template>
  {{! A label alone is a neutral pill }}
  <DPill @label={{label}} />

  {{! Every type, an icon, and attributes on the span }}
  <DPill @label={{label}} @type="neutral" />
  <DPill @label={{label}} @type="info" />
  <DPill @label={{label}} @type="success" />
  <DPill @label={{label}} @type="warning" />
  <DPill @label={{label}} @type="danger" />
  <DPill @icon="circle" @label={{label}} @type={{if live "success"}} />
  <DPill class="day" title="Wednesday" @label={{label}} />
</template>;

export default Test;
