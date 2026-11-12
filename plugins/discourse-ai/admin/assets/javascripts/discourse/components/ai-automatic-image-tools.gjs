import { LinkTo } from "@ember/routing";
import { i18n } from "discourse-i18n";

/**
 * The image-generation tools discovered by a system agent at runtime.
 *
 * @param {Array<{ id: number, name: string }>} tools
 */
const AiAutomaticImageTools = <template>
  <div class="ai-automatic-image-tools">
    <p class="ai-automatic-image-tools__description">
      {{i18n "discourse_ai.ai_agent.automatic_image_tools"}}
    </p>
    <ul class="ai-automatic-image-tools__list">
      {{#each @tools as |tool|}}
        <li>
          <LinkTo
            @model={{tool.id}}
            @route="adminPlugins.show.discourse-ai-tools.edit"
          >{{tool.name}}</LinkTo>
        </li>
      {{else}}
        <li class="ai-automatic-image-tools__empty">
          {{i18n "discourse_ai.ai_agent.no_image_tools"}}
        </li>
      {{/each}}
    </ul>
  </div>
</template>;

export default AiAutomaticImageTools;
