import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import ComboBox from "discourse/select-kit/components/combo-box";
import UserChooser from "discourse/select-kit/components/user-chooser";
import { i18n } from "discourse-i18n";
import {
  ACTOR_KIND,
  actorKindForValue,
  ANONYMOUS_ACTOR,
  SYSTEM_ACTOR,
} from "../../../lib/workflows/actor";
import ExpressionWrapper from "./expression-wrapper";

const KIND_OPTIONS = [
  { id: ACTOR_KIND.system, name: i18n("discourse_workflows.actor.system") },
  {
    id: ACTOR_KIND.anonymous,
    name: i18n("discourse_workflows.actor.anonymous"),
  },
  { id: ACTOR_KIND.user, name: i18n("discourse_workflows.actor.user") },
];

export default class ActorControl extends Component {
  @tracked kind = actorKindForValue(this.args.field.value);

  get showUserChooser() {
    return this.kind === ACTOR_KIND.user;
  }

  get username() {
    return this.args.field.value || null;
  }

  @action
  handleKindChange(kind) {
    this.kind = kind;

    if (kind === ACTOR_KIND.system) {
      this.args.field.set(SYSTEM_ACTOR);
    } else if (kind === ACTOR_KIND.anonymous) {
      this.args.field.set(ANONYMOUS_ACTOR);
    } else {
      const current = this.args.field.value;
      this.args.field.set(
        actorKindForValue(current) === ACTOR_KIND.user ? current : ""
      );
    }
  }

  @action
  handleUserChange(usernames) {
    this.args.field.set(usernames[0] || "");
  }

  <template>
    <ExpressionWrapper
      @dynamicValueHint={{@dynamicValueHint}}
      @field={{@field}}
      @placeholder={{@placeholder}}
      @schema={{@schema}}
      @session={{@session}}
      @supportsExpression={{@supportsExpression}}
    >
      <div class="workflows-actor-control">
        <ComboBox
          class="workflows-actor-control__kind"
          @content={{KIND_OPTIONS}}
          @nameProperty="name"
          @onChange={{this.handleKindChange}}
          @value={{this.kind}}
          @valueProperty="id"
        />

        {{#if this.showUserChooser}}
          <UserChooser
            class="workflows-actor-control__user"
            @onChange={{this.handleUserChange}}
            @options={{hash maximum=1 excludeCurrentUser=false}}
            @value={{this.username}}
          />
        {{/if}}
      </div>
    </ExpressionWrapper>
  </template>
}
