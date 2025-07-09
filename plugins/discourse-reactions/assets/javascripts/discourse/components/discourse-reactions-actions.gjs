import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel, later, run, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { createPopper } from "@popperjs/core";
import curryComponent from "ember-curry-component";
import $ from "jquery";
import { Promise } from "rsvp";
import { and, eq, not } from "truth-helpers";
import lazyHash from "discourse/helpers/lazy-hash";
import { isTesting } from "discourse/lib/environment";
import { emojiUrlFor } from "discourse/lib/text";
import closeOnClickOutside from "discourse/modifiers/close-on-click-outside";
import { i18n } from "discourse-i18n";
import CustomReaction from "../models/discourse-reactions-custom-reaction";
import DiscourseReactionsCounter from "./discourse-reactions-counter";
import DiscourseReactionsDoubleButton from "./discourse-reactions-double-button";
import DiscourseReactionsPicker from "./discourse-reactions-picker";
import DiscourseReactionsReactionButton from "./discourse-reactions-reaction-button";

const VIBRATE_DURATION = 5;

let _popperPicker;
let _currentReactionWidget;

export function resetCurrentReaction() {
  _currentReactionWidget = null;
}

function buildFakeReaction(reactionId) {
  const img = document.createElement("img");
  img.src = emojiUrlFor(reactionId);
  img.classList.add(
    "btn-toggle-reaction-emoji",
    "reaction-button",
    "fake-reaction"
  );

  return img;
}

function moveReactionAnimation(
  postContainer,
  reactionId,
  startPosition,
  endPosition,
  complete
) {
  if (isTesting()) {
    return;
  }

  const fakeReaction = buildFakeReaction(reactionId);
  const reactionButton = postContainer.querySelector(".reaction-button");

  reactionButton.appendChild(fakeReaction);

  let done = () => {
    fakeReaction.remove();
    complete();
  };

  fakeReaction.style.top = startPosition;
  fakeReaction.style.opacity = 0;

  $(fakeReaction).animate(
    {
      top: endPosition,
      opacity: 1,
    },
    {
      duration: 350,
      complete: done,
    },
    "swing"
  );
}

function addReaction(list, reactionId, complete) {
  moveReactionAnimation(list, reactionId, "-50px", "8px", complete);
}

function dropReaction(list, reactionId, complete) {
  moveReactionAnimation(list, reactionId, "8px", "42px", complete);
}

function scaleReactionAnimation(mainReaction, start, end, complete) {
  if (isTesting()) {
    return run(this, complete);
  }

  return $(mainReaction)
    .stop()
    .css("textIndent", start)
    .animate(
      { textIndent: end },
      {
        complete,
        step(now) {
          $(this)
            .css("transform", `scale(${now})`)
            .addClass("far-heart")
            .removeClass("heart");
        },
        duration: 150,
      },
      "linear"
    );
}

export default class DiscourseReactionsActions extends Component {
  @service dialog;
  @service capabilities;
  @service siteSettings;
  @service site;
  @service currentUser;

  @tracked reactionsPickerExpanded = false;
  @tracked statePanelExpanded = false;

  get classes() {
    const { post } = this.args;
    if (!post.reactions) {
      return;
    }

    const hasReactions = post.reactions.length;
    const hasReacted = post.current_user_reaction;
    const customReactionUsed =
      post.reactions.length &&
      post.reactions.filter(
        (reaction) =>
          reaction.id !==
          this.siteSettings.discourse_reactions_reaction_for_like
      ).length;
    const classes = [];

    if (customReactionUsed) {
      classes.push("custom-reaction-used");
    }

    if (post.yours) {
      classes.push("my-post");
    }

    if (hasReactions) {
      classes.push("has-reactions");
    }

    if (hasReacted) {
      classes.push("has-reacted");
    }

    if (post.current_user_used_main_reaction) {
      classes.push("has-used-main-reaction");
    }

    if (
      (!post.current_user_reaction || post.current_user_reaction.can_undo) &&
      post.likeAction?.canToggle
    ) {
      classes.push("can-toggle-reaction");
    }

    return classes.join(" ");
  }

  @action
  toggleReactions(event) {
    if (!this.reactionsPickerExpanded) {
      if (this.statePanelExpanded) {
        this.scheduleExpand("expandReactionsPicker");
      } else {
        this.expandReactionsPicker(event);
      }
    }
  }

  @action
  touchStart() {
    this._validTouch = true;

    cancel(this._touchTimeout);

    if (this.capabilities.touch) {
      document.documentElement?.classList?.toggle(
        "discourse-reactions-no-select",
        true
      );

      this._touchStartAt = Date.now();
      this._touchTimeout = later(() => {
        this._touchStartAt = null;
        this.toggleReactions();
      }, 400);
      return false;
    }
  }

  @action
  touchMove() {
    // if users move while touching we consider it as a scroll and don't want to
    // trigger the reaction or the picker
    this._validTouch = false;
    cancel(this._touchTimeout);
  }

  @action
  touchEnd(event) {
    cancel(this._touchTimeout);

    if (!this._validTouch) {
      return;
    }

    if (this.capabilities.touch) {
      if (event.changedTouches.length) {
        const endTarget = document.elementFromPoint(
          event.changedTouches[0].clientX,
          event.changedTouches[0].clientY
        );

        if (endTarget) {
          const parentNode = endTarget.parentNode;

          if (endTarget.classList.contains("pickable-reaction")) {
            endTarget.click();
            return;
          } else if (
            parentNode &&
            parentNode.classList.contains("pickable-reaction")
          ) {
            parentNode.click();
            return;
          }
        }
      }

      const duration = Date.now() - (this._touchStartAt || 0);
      this._touchStartAt = null;
      if (duration > 400) {
        if (
          event &&
          event.target &&
          event.target.classList.contains("discourse-reactions-reaction-button")
        ) {
          this.toggleReactions(event);
        }
      } else {
        if (
          event.target &&
          (event.target.classList.contains(
            "discourse-reactions-reaction-button"
          ) ||
            event.target.classList.contains("reaction-button"))
        ) {
          this.toggleFromButton({
            reaction: this.args.post.current_user_reaction
              ? this.args.post.current_user_reaction.id
              : this.siteSettings.discourse_reactions_reaction_for_like,
          });
        }
      }
    }
  }

  @action
  toggle(params) {
    if (!this.currentUser) {
      if (this.args.showLogin) {
        this.args.showLogin();
        return;
      }
    }

    if (
      !this.args.post.current_user_reaction ||
      (this.args.post.current_user_reaction.can_undo &&
        this.args.post.likeAction.canToggle)
    ) {
      if (this.capabilities.userHasBeenActive && this.capabilities.canVibrate) {
        navigator.vibrate(VIBRATE_DURATION);
      }

      const pickedReaction = document.querySelector(
        `[data-post-id="${
          params.postId
        }"] .discourse-reactions-picker .pickable-reaction.${CSS.escape(
          params.reaction
        )} .emoji`
      );

      const scales = [1.0, 1.75];
      return new Promise((resolve) => {
        scaleReactionAnimation(pickedReaction, scales[0], scales[1], () => {
          scaleReactionAnimation(pickedReaction, scales[1], scales[0], () => {
            const post = this.args.post;
            const postContainer = document.querySelector(
              `[data-post-id="${params.postId}"]`
            );

            if (
              post.current_user_reaction &&
              post.current_user_reaction.id === params.reaction
            ) {
              this.toggleReaction(params);

              later(() => {
                dropReaction(postContainer, params.reaction, () => {
                  return CustomReaction.toggle(this.args.post, params.reaction)
                    .then(resolve)
                    .catch((e) => {
                      this.dialog.alert(this._extractErrors(e));
                      this._rollbackState(post);
                    });
                });
              }, 100);
            } else {
              addReaction(postContainer, params.reaction, () => {
                this.toggleReaction(params);

                CustomReaction.toggle(this.args.post, params.reaction)
                  .then(resolve)
                  .catch((e) => {
                    this.dialog.alert(this._extractErrors(e));
                    this._rollbackState(post);
                  });
              });
            }
          });
        });
      }).finally(() => {
        this.collapseAllPanels();
      });
    }
  }

  toggleReaction(attrs) {
    this.collapseAllPanels();

    if (
      this.args.post.current_user_reaction &&
      !this.args.post.current_user_reaction.can_undo &&
      !this.args.post.likeAction.canToggle
    ) {
      return;
    }

    const post = this.args.post;

    if (post.current_user_reaction) {
      post.reactions.every((reaction, index) => {
        if (
          reaction.count <= 1 &&
          reaction.id === post.current_user_reaction.id
        ) {
          post.reactions.splice(index, 1);
          return false;
        } else if (reaction.id === post.current_user_reaction.id) {
          post.reactions[index].count -= 1;

          return false;
        }

        return true;
      });
    }

    if (
      attrs.reaction &&
      (!post.current_user_reaction ||
        attrs.reaction !== post.current_user_reaction.id)
    ) {
      let isAvailable = false;

      post.reactions.every((reaction, index) => {
        if (reaction.id === attrs.reaction) {
          post.reactions[index].count += 1;
          isAvailable = true;
          return false;
        }
        return true;
      });

      if (!isAvailable) {
        const newReaction = {
          id: attrs.reaction,
          type: "emoji",
          count: 1,
        };

        const tempReactions = Object.assign([], post.reactions);

        tempReactions.push(newReaction);

        //sorts reactions and get index of new reaction
        const newReactionIndex = tempReactions
          .sort((reaction1, reaction2) => {
            if (reaction1.count > reaction2.count) {
              return -1;
            }
            if (reaction1.count < reaction2.count) {
              return 1;
            }

            //if count is same, sort it by id
            if (reaction1.id > reaction2.id) {
              return 1;
            }
            if (reaction1.id < reaction2.id) {
              return -1;
            }
          })
          .indexOf(newReaction);

        post.reactions.splice(newReactionIndex, 0, newReaction);
      }

      if (!post.current_user_reaction) {
        post.reaction_users_count += 1;
      }

      post.current_user_reaction = {
        id: attrs.reaction,
        type: "emoji",
        can_undo: true,
      };
    } else {
      post.reaction_users_count -= 1;
      post.current_user_reaction = null;
    }

    if (
      post.current_user_reaction &&
      post.current_user_reaction.id ===
        this.siteSettings.discourse_reactions_reaction_for_like
    ) {
      post.current_user_used_main_reaction = true;
    } else {
      post.current_user_used_main_reaction = false;
    }

    // Trigger re-render for anything autotracking reactions.
    // In future, we should make reactions a deeply-trackable structure.
    // eslint-disable-next-line no-self-assign
    post.reactions = post.reactions;
  }

  @action
  toggleFromButton(attrs) {
    if (!this.currentUser) {
      if (this.args.showLogin) {
        this.args.showLogin();
        return;
      }
    }

    this.collapseAllPanels();

    const mainReactionName =
      this.siteSettings.discourse_reactions_reaction_for_like;
    const post = this.args.post;
    const current_user_reaction = post.current_user_reaction;

    if (
      post.likeAction &&
      !(post.likeAction.canToggle || post.likeAction.can_undo)
    ) {
      return;
    }

    if (
      this.args.post.current_user_reaction &&
      !this.args.post.current_user_reaction.can_undo
    ) {
      return;
    }

    if (!this.currentUser || post.user_id === this.currentUser.id) {
      return;
    }

    if (this.capabilities.userHasBeenActive && this.capabilities.canVibrate) {
      navigator.vibrate(VIBRATE_DURATION);
    }

    if (current_user_reaction && current_user_reaction.id === attrs.reaction) {
      this.toggleReaction(attrs);
      return CustomReaction.toggle(this.args.post, attrs.reaction).catch(
        (e) => {
          this.dialog.alert(this._extractErrors(e));
          this._rollbackState(post);
        }
      );
    }

    let selector;
    if (
      post.reactions &&
      post.reactions.length === 1 &&
      post.reactions[0].id === mainReactionName
    ) {
      selector = `[data-post-id="${this.args.post.id}"] .discourse-reactions-double-button .discourse-reactions-reaction-button .d-icon`;
    } else {
      if (!attrs.reaction || attrs.reaction === mainReactionName) {
        selector = `[data-post-id="${this.args.post.id}"] .discourse-reactions-reaction-button .d-icon`;
      } else {
        selector = `[data-post-id="${this.args.post.id}"] .discourse-reactions-reaction-button .reaction-button .btn-toggle-reaction-emoji`;
      }
    }

    const mainReaction = document.querySelector(selector);

    const scales = [1.0, 1.5];
    return new Promise((resolve) => {
      scaleReactionAnimation(mainReaction, scales[0], scales[1], () => {
        scaleReactionAnimation(mainReaction, scales[1], scales[0], () => {
          this.toggleReaction(attrs);

          let toggleReaction =
            attrs.reaction && attrs.reaction !== mainReactionName
              ? attrs.reaction
              : this.siteSettings.discourse_reactions_reaction_for_like;

          CustomReaction.toggle(this.args.post, toggleReaction)
            .then(resolve)
            .catch((e) => {
              this.dialog.alert(this._extractErrors(e));
              this._rollbackState(post);
            });
        });
      });
    });
  }

  @action
  cancelCollapse() {
    cancel(this._collapseHandler);
  }

  @action
  cancelExpand() {
    cancel(this._expandHandler);
  }

  scheduleExpand(handler) {
    this.cancelExpand();

    this._expandHandler = later(this, this[handler], 250);
  }

  @action
  scheduleCollapse(handler) {
    this.cancelCollapse();

    this._collapseHandler = later(this, this[handler], 500);
  }

  get elementId() {
    return `discourse-reactions-actions-${this.args.post.id}-${
      this.args.position || "right"
    }`;
  }

  @action
  clickOutside() {
    if (this.reactionsPickerExpanded || this.statePanelExpanded) {
      this.collapseAllPanels();
    }
  }

  expandReactionsPicker() {
    cancel(this._collapseHandler);
    _currentReactionWidget?.collapseAllPanels();
    this.statePanelExpanded = false;
    this.reactionsPickerExpanded = true;
    this._setupPopper([
      ".discourse-reactions-reaction-button",
      ".discourse-reactions-picker",
    ]);
  }

  @action
  expandStatePanel() {
    cancel(this._collapseHandler);
    _currentReactionWidget?.collapseAllPanels();
    this.statePanelExpanded = true;
    this.reactionsPickerExpanded = false;
    this._setupPopper([
      ".discourse-reactions-counter",
      ".discourse-reactions-state-panel",
    ]);
  }

  @action
  collapseStatePanel() {
    cancel(this._collapseHandler);
    this._collapseHandler = null;
    this.statePanelExpanded = false;
  }

  collapseReactionsPicker() {
    cancel(this._collapseHandler);
    this._collapseHandler = null;
    this.reactionsPickerExpanded = false;
  }

  @action
  collapseAllPanels() {
    cancel(this._collapseHandler);
    document.documentElement?.classList?.toggle(
      "discourse-reactions-no-select",
      false
    );
    this._collapseHandler = null;
    this.statePanelExpanded = false;
    this.reactionsPickerExpanded = false;
  }

  @action
  updatePopperPosition() {
    _popperPicker?.update();
  }

  _setupPopper(selectors) {
    schedule("afterRender", () => {
      const position = this.args.position || "right";
      const id = this.args.post.id;
      const trigger = document.querySelector(
        `#discourse-reactions-actions-${id}-${position} ${selectors[0]}`
      );
      const popper = document.querySelector(
        `#discourse-reactions-actions-${id}-${position} ${selectors[1]}`
      );

      _popperPicker?.destroy();
      _popperPicker = this._applyPopper(trigger, popper);
      _currentReactionWidget = this;
    });
  }

  _applyPopper(button, picker) {
    return createPopper(button, picker, {
      placement: "top",
      modifiers: [
        {
          name: "offset",
          options: {
            offset: [0, -5],
          },
        },
        {
          name: "preventOverflow",
          options: {
            padding: 5,
          },
        },
      ],
    });
  }

  _rollbackState(post) {
    const current_user_reaction = post.current_user_reaction;
    const current_user_used_main_reaction =
      post.current_user_used_main_reaction;
    const reactions = Object.assign([], post.reactions);
    const reaction_users_count = post.reaction_users_count;

    post.current_user_reaction = current_user_reaction;
    post.current_user_used_main_reaction = current_user_used_main_reaction;
    post.reactions = reactions;
    post.reaction_users_count = reaction_users_count;
  }

  _extractErrors(e) {
    const xhr = e.xhr || e.jqXHR;

    if (!xhr || !xhr.status) {
      return i18n("errors.desc.network");
    }

    if (
      xhr.status === 429 &&
      xhr.responseJSON &&
      xhr.responseJSON.errors &&
      xhr.responseJSON.errors[0]
    ) {
      return xhr.responseJSON.errors[0];
    } else if (xhr.status === 403) {
      return i18n("discourse_reactions.reaction.forbidden");
    } else {
      return i18n("errors.desc.unknown");
    }
  }

  get onlyOneMainReaction() {
    return (
      this.args.post.reactions?.length === 1 &&
      this.args.post.reactions[0].id ===
        this.siteSettings.discourse_reactions_reaction_for_like
    );
  }

  get showReactionsPicker() {
    return (
      this.currentUser &&
      this.args.post.user_id !== this.currentUser.id &&
      this.reactionsPickerExpanded
    );
  }

  <template>
    <div
      id={{this.elementId}}
      class="discourse-reactions-actions {{this.classes}}"
      {{on "touchstart" this.touchStart}}
      {{on "touchmove" this.touchMove}}
      {{on "touchend" this.touchEnd}}
      {{closeOnClickOutside this.clickOutside (hash)}}
    >
      {{#let
        (hash
          counter=(curryComponent
            DiscourseReactionsCounter
            (lazyHash
              post=@post
              position=@position
              reactionsPickerExpanded=this.reactionsPickerExpanded
              statePanelExpanded=this.statePanelExpanded
              expandStatePanel=this.expandStatePanel
              collapseStatePanel=this.collapseStatePanel
              cancelCollapse=this.cancelCollapse
              scheduleCollapse=this.scheduleCollapse
              updatePopperPosition=this.updatePopperPosition
              collapseAllPanels=this.collapseAllPanels
            )
          )
          button=(curryComponent
            DiscourseReactionsReactionButton
            (lazyHash
              post=@post
              position=@position
              cancelCollapse=this.cancelCollapse
              toggleFromButton=this.toggleFromButton
              toggleReactions=this.toggleReactions
              cancelExpand=this.cancelExpand
              scheduleCollapse=this.scheduleCollapse
            )
          )
        )
        as |components|
      }}
        {{#if this.showReactionsPicker}}
          <DiscourseReactionsPicker
            @post={{@post}}
            @scheduleCollapse={{this.scheduleCollapse}}
            @cancelCollapse={{this.cancelCollapse}}
            @reactionsPickerExpanded={{this.reactionsPickerExpanded}}
            @toggle={{this.toggle}}
          />
        {{/if}}

        {{#if (eq @position "left")}}
          <components.counter />
        {{else if this.onlyOneMainReaction}}
          <DiscourseReactionsDoubleButton
            @post={{@post}}
            @counterComponent={{components.counter}}
            @buttonComponent={{components.button}}
          />
        {{else if this.site.mobileView}}
          {{#if (not @post.yours)}}
            <components.counter />
            <components.button />
          {{else if (and @post.yours @post.reactions @post.reactions.length)}}
            <components.counter />
          {{/if}}
        {{else if (not @post.yours)}}
          <components.button />
        {{/if}}
      {{/let}}
    </div>
  </template>
}
