import Component from "@glimmer/component";
import { isGPTBot } from "../../lib/ai-bot-helper";

export default class AiAgentFlair extends Component {
  static shouldRender(args) {
    return isGPTBot(args.post.user);
  }

  get agentName() {
    return this.args.outletArgs.post.topic.ai_agent_name;
  }

  <template>
    <span class="agent-flair">{{this.agentName}}</span>
  </template>
}
