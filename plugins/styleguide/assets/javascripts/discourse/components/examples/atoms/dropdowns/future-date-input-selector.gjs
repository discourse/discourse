import { hash } from "@ember/helper";
import FutureDateInputSelector from "discourse/select-kit/components/future-date-input-selector";

export default <template>
  <FutureDateInputSelector
    @includeForever={{true}}
    @includeWeekend={{true}}
    @input="2017-10-18 18:00"
    @options={{hash none="time_shortcut.select_timeframe"}}
  />
</template>
