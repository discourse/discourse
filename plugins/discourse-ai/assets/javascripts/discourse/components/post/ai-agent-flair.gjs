import Component from "@glimmer/component";
import DUserLink from "discourse/ui-kit/d-user-link";
import { isGPTBot } from "../../lib/ai-bot-helper";

export default class AiAgentFlair extends Component {
  static shouldRender(args) {
    return (
      args.post.llm_name || args.post.ai_agent_id || isGPTBot(args.post.user)
    );
  }

  get agentName() {
    return this.args.outletArgs.post.ai_agent_name;
  }

  get modelName() {
    return this.args.outletArgs.post.llm_name;
  }

  get user() {
    return this.args.outletArgs.user || this.args.outletArgs.post.user;
  }

  <template>
    {{#if this.agentName}}
      <span class="agent-flair">
        <DUserLink @user={{this.user}}>{{this.agentName}}</DUserLink>
      </span>
    {{else}}
      {{yield}}
    {{/if}}
    {{#if this.modelName}}
      <span class="agent-flair__model">{{this.modelName}}</span>
    {{/if}}
  </template>
}
