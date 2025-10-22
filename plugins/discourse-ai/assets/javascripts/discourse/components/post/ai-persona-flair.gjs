import Component from "@glimmer/component";
import { isGPTBot } from "../../lib/ai-bot-helper";

export default class AiPersonaFlair extends Component {
  static shouldRender(args) {
    return isGPTBot(args.post.user);
  }

  <template>
    <span class="persona-flair">
      {{@outletArgs.post.topic.ai_persona_name}}
    </span>
  </template>
}
