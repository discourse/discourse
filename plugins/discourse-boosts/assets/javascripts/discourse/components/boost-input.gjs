import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import EmojiPicker from "discourse/components/emoji-picker";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import KeyValueStore from "discourse/lib/key-value-store";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import BoostEditor from "./boost-editor";

const STORE_NAMESPACE = "discourse_boosts_";
const TIP_SEEN_KEY = "tip_seen";

const BoostTip = <template>
  <div class="discourse-boosts__tip">
    {{htmlSafe (i18n "discourse_boosts.action_title")}}
    <span class="discourse-boosts__tip-username">
      @{{@data.username}}
    </span>
    {{i18n "discourse_boosts.tip"}}
  </div>
</template>;

export default class BoostInput extends Component {
  @service currentUser;
  @service site;
  @service tooltip;

  @tracked value = "";

  store = new KeyValueStore(STORE_NAMESPACE);

  willDestroy() {
    super.willDestroy(...arguments);
    this.tooltip.close("discourse-boosts-tip");
  }

  @action
  maybeShowTip(element) {
    if (this.store.get(TIP_SEEN_KEY)) {
      return;
    }

    this.store.set({ key: TIP_SEEN_KEY, value: true });

    next(() => {
      this.tooltip.show(element, {
        identifier: "discourse-boosts-tip",
        placement: "top",
        component: BoostTip,
        data: {
          username: this.args.post.username,
        },
      });
    });
  }

  get canSubmit() {
    return this.value.trim().length > 0;
  }

  get placeholder() {
    return i18n("discourse_boosts.boost_input_placeholder", {
      username: this.args.post.username,
    });
  }

  @action
  handleChange(newValue) {
    this.value = newValue;
  }

  @action
  submit() {
    if (this.canSubmit) {
      this.args.onSubmit(this.value.trim());
    }
  }

  @action
  closeTip() {
    this.tooltip.close("discourse-boosts-tip");
  }

  <template>
    <div
      class="discourse-boosts__input-container"
      {{didInsert this.maybeShowTip}}
    >
      {{boundAvatarTemplate this.currentUser.avatar_template "small"}}
      <BoostEditor
        @placeholder={{this.placeholder}}
        @onChange={{this.handleChange}}
        @onSubmit={{this.submit}}
        @onClose={{@onClose}}
        as |editor|
      >
        {{#if this.site.desktopView}}
          <EmojiPicker
            @didSelectEmoji={{editor.insertEmoji}}
            @onShow={{this.closeTip}}
            @onClose={{editor.focus}}
            @btnClass="btn-transparent discourse-boosts__emoji-btn"
            @context="boost"
            @modalForMobile={{false}}
            @disabled={{not editor.canAddEmoji}}
          />
        {{/if}}
        <DButton
          @action={{this.submit}}
          @icon="check"
          @disabled={{not this.canSubmit}}
          @ariaLabel="discourse_boosts.submit"
          @title="discourse_boosts.submit"
          class="btn-default --success btn-icon-only discourse-boosts__submit"
        />
        <DButton
          @action={{@onClose}}
          @icon="xmark"
          @ariaLabel="discourse_boosts.cancel"
          @title="discourse_boosts.cancel"
          class="btn-default --danger btn-icon-only discourse-boosts__cancel"
        />
      </BoostEditor>
    </div>
  </template>
}
