import { getOwnerWithFallback } from "discourse/lib/get-owner";
import UserNotesModal from "../../discourse/components/modal/user-notes";

export function showUserNotes(store, userId, callback, opts) {
  const modal = getOwnerWithFallback(this).lookup("service:modal");
  opts = opts || {};

  return store.find("user-note", { user_id: userId }).then((model) => {
    return modal.show(UserNotesModal, {
      model: {
        note: model,
        userId,
        callback,
        postId: opts.postId,
      },
    });
  });
}

export function updatePostUserNotesCount(post, count) {
  const cfs = post.user_custom_fields || {};
  cfs.user_notes_count = count;
  post.user_custom_fields = cfs;
}
