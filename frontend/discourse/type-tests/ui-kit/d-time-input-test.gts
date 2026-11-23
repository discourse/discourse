import type { Moment } from "moment";
import DTimeInput from "discourse/ui-kit/d-time-input";

declare const date: Moment;

const Positives = <template>
  <DTimeInput @date={{date}} @relativeDate={{date}} />
  <DTimeInput @hours="14" @minutes={{30}} />
</template>;

export default Positives;
