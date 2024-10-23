import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import UserTipContainer from "discourse/components/user-tip-container";
import helperFn from "discourse/helpers/helper-fn";
import escape from "discourse-common/lib/escape";
import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "discourse-i18n";
import DTooltipInstance from "float-kit/lib/d-tooltip-instance";

export default class UserTip extends Component {
  @service currentUser;
  @service userTips;
  @service tooltip;

  registerTip = helperFn((_, on) => {
    const tip = {
      id: this.args.id,
      priority: this.args.priority ?? 0,
    };

    this.userTips.addAvailableTip(tip);

    on.cleanup(() => {
      this.userTips.removeAvailableTip(tip);
    });
  });

  tip = modifier((element) => {
    let instance;
    schedule("afterRender", () => {
      const trigger =
        this.args.triggerSelector &&
        document.querySelector(this.args.triggerSelector);

      let buttonText = escape(
        I18n.t(this.args.buttonLabel || "user_tips.button")
      );
      if (this.args.buttonIcon) {
        buttonText = `${iconHTML(this.args.buttonIcon)} ${buttonText}`;
      }

      instance = new DTooltipInstance(getOwner(this), {
        identifier: "user-tip",
        interactive: true,
        closeOnScroll: false,
        closeOnClickOutside: true,
        placement: this.args.placement,
        component: UserTipContainer,
        data: {
          id: this.args.id,
          titleText: escape(this.args.titleText),
          contentHtml: this.args.contentHtml || null,
          contentText: this.args.contentText
            ? escape(this.args.contentText)
            : null,
          buttonText,
          buttonSkipText: I18n.t("user_tips.skip"),
          showSkipButton: this.args.showSkipButton,
        },
      });
      instance.trigger = trigger || element;
      instance.detachedTrigger = true;

      this.tooltip.show(instance);

      if (this.shouldRenderTip) {
        // mark tooltip directly as seen so that
        // refreshing, clicking outside, etc. won't show it again
        this.userTips.markAsSeen(this.args.id);
      }
    });

    return () => {
      instance?.destroy();
    };
  });

  get shouldRenderTip() {
    return this.userTips.shouldRender(this.args.id);
  }

  <template>
    {{this.registerTip}}
    {{#if this.shouldRenderTip}}
      <span {{this.tip}}></span>
    {{/if}}
  </template>
}
