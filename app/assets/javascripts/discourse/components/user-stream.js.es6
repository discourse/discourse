import { schedule } from "@ember/runloop";
import Component from "@ember/component";
import LoadMore from "discourse/mixins/load-more";
import ClickTrack from "discourse/lib/click-track";
import Post from "discourse/models/post";
import DiscourseURL from "discourse/lib/url";
import Draft from "discourse/models/draft";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getOwner } from "discourse-common/lib/get-owner";

export default Component.extend(LoadMore, {
  _initialize: Ember.on("init", function() {
    const filter = this.get("stream.filter");
    if (filter) {
      this.set("classNames", [
        "user-stream",
        "filter-" + filter.toString().replace(",", "-")
      ]);
    }
  }),

  loading: false,
  eyelineSelector: ".user-stream .item",
  classNames: ["user-stream"],

  _scrollTopOnModelChange: function() {
    schedule("afterRender", () => $(document).scrollTop(0));
  }.observes("stream.user.id"),

  _inserted: Ember.on("didInsertElement", function() {
    this.bindScrolling({ name: "user-stream-view" });

    $(window).on("resize.discourse-on-scroll", () => this.scrolled());

    $(this.element).on(
      "click.details-disabled",
      "details.disabled",
      () => false
    );
    $(this.element).on("click.discourse-redirect", ".excerpt a", function(e) {
      return ClickTrack.trackClick(e);
    });
  }),

  // This view is being removed. Shut down operations
  _destroyed: Ember.on("willDestroyElement", function() {
    this.unbindScrolling("user-stream-view");
    $(window).unbind("resize.discourse-on-scroll");
    $(this.element).off("click.details-disabled", "details.disabled");

    // Unbind link tracking
    $(this.element).off("click.discourse-redirect", ".excerpt a");
  }),

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
          .then(d => {
            const draft = d.draft || item.data;
            if (!draft) {
              return;
            }

            composer.open({
              draft,
              draftKey: item.draft_key,
              draftSequence: d.draft_sequence
            });
          })
          .catch(error => {
            popupAjaxError(error);
          });
      }
    },

    removeDraft(draft) {
      const stream = this.stream;
      Draft.clear(draft.draft_key, draft.sequence)
        .then(() => {
          stream.remove(draft);
        })
        .catch(error => {
          popupAjaxError(error);
        });
    },

    loadMore() {
      if (this.loading) {
        return;
      }

      this.set("loading", true);
      const stream = this.stream;
      stream.findItems().then(() => {
        this.set("loading", false);
        this.eyeline.flushRest();
      });
    }
  }
});
