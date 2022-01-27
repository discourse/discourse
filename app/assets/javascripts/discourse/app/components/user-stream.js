import ClickTrack from "discourse/lib/click-track";
import Component from "@ember/component";
import DiscourseURL from "discourse/lib/url";
import Draft from "discourse/models/draft";
import I18n from "I18n";
import LoadMore from "discourse/mixins/load-more";
import Post from "discourse/models/post";
import { NEW_TOPIC_KEY } from "discourse/models/composer";
import bootbox from "bootbox";
import { getOwner } from "discourse-common/lib/get-owner";
import { observes } from "discourse-common/utils/decorators";
import { on } from "@ember/object/evented";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { schedule } from "@ember/runloop";

export default Component.extend(LoadMore, {
  tagName: "ul",
  _lastDecoratedElement: null,

  _initialize: on("init", function () {
    const filter = this.get("stream.filter");
    if (filter) {
      this.set("classNames", [
        "user-stream",
        "filter-" + filter.toString().replace(",", "-"),
      ]);
    }
  }),

  loading: false,
  eyelineSelector: ".user-stream .item",
  classNames: ["user-stream"],

  @observes("stream.user.id")
  _scrollTopOnModelChange() {
    schedule("afterRender", () => $(document).scrollTop(0));
  },

  _inserted: on("didInsertElement", function () {
    $(window).on("resize.discourse-on-scroll", () => this.scrolled());

    $(this.element).on(
      "click.details-disabled",
      "details.disabled",
      () => false
    );
    $(this.element).on("click.discourse-redirect", ".excerpt a", (e) => {
      return ClickTrack.trackClick(e, this.siteSettings);
    });
    this._updateLastDecoratedElement();
  }),

  // This view is being removed. Shut down operations
  _destroyed: on("willDestroyElement", function () {
    $(window).unbind("resize.discourse-on-scroll");
    $(this.element).off("click.details-disabled", "details.disabled");

    // Unbind link tracking
    $(this.element).off("click.discourse-redirect", ".excerpt a");
  }),

  _updateLastDecoratedElement() {
    const nodes = this.element.querySelectorAll(".user-stream-item");
    if (nodes.length === 0) {
      return;
    }
    const lastElement = nodes[nodes.length - 1];
    if (lastElement === this._lastDecoratedElement) {
      return;
    }
    this._lastDecoratedElement = lastElement;
  },

  actions: {
    removeBookmark(userAction) {
      const stream = this.stream;
      Post.updateBookmark(userAction.get("post_id"), false)
        .then(() => {
          stream.remove(userAction);
        })
        .catch(popupAjaxError);
    },

    resumeDraft(item) {
      const composer = getOwner(this).lookup("controller:composer");
      if (composer.get("model.viewOpen")) {
        composer.close();
      }
      if (item.get("postUrl")) {
        DiscourseURL.routeTo(item.get("postUrl"));
      } else {
        Draft.get(item.draft_key)
          .then((d) => {
            const draft = d.draft || item.data;
            if (!draft) {
              return;
            }

            composer.open({
              draft,
              draftKey: item.draft_key,
              draftSequence: d.draft_sequence,
            });
          })
          .catch((error) => {
            popupAjaxError(error);
          });
      }
    },

    removeDraft(draft) {
      const stream = this.stream;
      bootbox.confirm(
        I18n.t("drafts.remove_confirmation"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        (confirmed) => {
          if (confirmed) {
            Draft.clear(draft.draft_key, draft.sequence)
              .then(() => {
                stream.remove(draft);
                if (draft.draft_key === NEW_TOPIC_KEY) {
                  this.currentUser.set("has_topic_draft", false);
                }
              })
              .catch((error) => {
                popupAjaxError(error);
              });
          }
        }
      );
    },

    loadMore() {
      if (this.loading) {
        return;
      }

      this.set("loading", true);
      const stream = this.stream;
      stream.findItems().then(() => {
        this.set("loading", false);
        let element = this._lastDecoratedElement?.nextElementSibling;
        while (element) {
          this.trigger("user-stream:new-item-inserted", element);
          element = element.nextElementSibling;
        }
        this._updateLastDecoratedElement();
      });
    },
  },
});
