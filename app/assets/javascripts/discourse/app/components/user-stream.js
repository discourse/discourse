import Component from "@ember/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { later } from "@ember/runloop";
import { service } from "@ember/service";
import { classNames, tagName } from "@ember-decorators/component";
import { on } from "@ember-decorators/object";
import $ from "jquery";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ClickTrack from "discourse/lib/click-track";
import DiscourseURL from "discourse/lib/url";
import LoadMore from "discourse/mixins/load-more";
import Draft from "discourse/models/draft";
import Post from "discourse/models/post";
import { i18n } from "discourse-i18n";

@tagName("ul")
@classNames("user-stream")
export default class UserStream extends Component.extend(LoadMore) {
  @service dialog;
  @service composer;

  loading = false;
  eyelineSelector = ".user-stream .item";
  _lastDecoratedElement = null;

  @on("init")
  _initialize() {
    const filter = this.get("stream.filter");
    if (filter) {
      this.set("classNames", [
        "user-stream",
        "filter-" + filter.toString().replace(",", "-"),
      ]);
    }
  }

  @on("didInsertElement")
  _inserted() {
    $(this.element).on(
      "click.details-disabled",
      "details.disabled",
      () => false
    );
    $(this.element).on("click.discourse-redirect", ".excerpt a", (e) => {
      return ClickTrack.trackClick(e, getOwner(this));
    });
    this._updateLastDecoratedElement();
    this.appEvents.trigger("decorate-non-stream-cooked-element", this.element);
  }

  // This view is being removed. Shut down operations
  @on("willDestroyElement")
  _destroyed() {
    $(this.element).off("click.details-disabled", "details.disabled");

    // Unbind link tracking
    $(this.element).off("click.discourse-redirect", ".excerpt a");
  }

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
  }

  @action
  removeBookmark(userAction) {
    const stream = this.stream;
    Post.updateBookmark(userAction.get("post_id"), false)
      .then(() => {
        stream.remove(userAction);
      })
      .catch(popupAjaxError);
  }

  @action
  resumeDraft(item) {
    if (this.composer.get("model.viewOpen")) {
      this.composer.close();
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

          this.composer.open({
            draft,
            draftKey: item.draft_key,
            draftSequence: d.draft_sequence,
          });
        })
        .catch((error) => {
          popupAjaxError(error);
        });
    }
  }

  @action
  removeDraft(draft) {
    const stream = this.stream;

    this.dialog.yesNoConfirm({
      message: i18n("drafts.remove_confirmation"),
      didConfirm: () => {
        Draft.clear(draft.draft_key, draft.sequence)
          .then(() => {
            stream.remove(draft);
          })
          .catch((error) => {
            popupAjaxError(error);
          });
      },
    });
  }

  @action
  loadMore() {
    if (this.loading) {
      return;
    }

    this.set("loading", true);
    const stream = this.stream;
    stream.findItems().then(() => {
      this.set("loading", false);

      // The next elements are not rendered on the page yet, we need to
      // wait for that before trying to decorate them.
      later(() => {
        let element = this._lastDecoratedElement?.nextElementSibling;
        while (element) {
          this.trigger("user-stream:new-item-inserted", element);
          this.appEvents.trigger("decorate-non-stream-cooked-element", element);
          element = element.nextElementSibling;
        }
        this._updateLastDecoratedElement();
      });
    });
  }
}
