import { i18n } from "discourse-i18n";
import AiBlinkingAnimation from "./ai-blinking-animation";
import AiIndicatorWave from "./ai-indicator-wave";

const AiSummarySkeleton = <template>
  <div class="ai-summary__container">
    <AiBlinkingAnimation />

    <span>
      <div class="ai-summary__generating-text">
        {{i18n "summary.in_progress"}}
      </div>
      <AiIndicatorWave @loading={{true}} />
    </span>
  </div>
</template>;

export default AiSummarySkeleton;
