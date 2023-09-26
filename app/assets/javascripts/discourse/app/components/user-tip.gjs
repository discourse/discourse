import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { modifier } from "ember-modifier";
import UserTipContainer from "discourse/components/user-tip-container";
import DTooltipInstance from "float-kit/lib/d-tooltip-instance";
import { getOwner } from "@ember/application";
import { schedule } from "@ember/runloop";
import { escape } from "pretty-text/sanitizer";
import I18n from "I18n";
import { iconHTML } from "discourse-common/lib/icon-library";

export default class UserTip extends Component {
  <template>
    {{! template-lint-disable modifier-name-case }}
    <div {{this.registerTip}}>
      {{#if this.shouldRenderTip}}
        <span {{this.tip}}></span>
      {{/if}}
    </div>
  </template>

  @service currentUser;
  @service userTips;
  @service tooltip;

  registerTip = modifier(() => {
    this.userTips.addAvailableTip({
      id: this.args.id,
      priority: this.args.priority ?? 0,
    });

    return () => {
      this.userTips.removeAvailableTip({ id: this.args.id });
    };
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

      instance = new DTooltipInstance(getOwner(this), trigger || element, {
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
          onDismiss: () => {
            this.userTips.hideUserTipForever(this.args.id);
          },
          buttonText,
        },
      });

      this.tooltip.show(instance);
    });

    return () => {
      instance?.destroy();
    };
  });

  get shouldRenderTip() {
    return this.userTips.renderedId === this.args.id;
  }
}
