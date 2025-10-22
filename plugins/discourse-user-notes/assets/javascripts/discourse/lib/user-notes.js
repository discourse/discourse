import { getOwnerWithFallback } from "discourse/lib/get-owner";
import UserNotesModal from "../components/modal/user-notes";

export async function showUserNotes(store, userId, callback, opts = {}) {
  const modal = getOwnerWithFallback(this).lookup("service:modal");

  const model = await store.find("user-note", { user_id: userId });

  await modal.show(UserNotesModal, {
    model: {
      note: model,
      userId,
      callback,
      postId: opts.postId,
    },
  });
}

export function updatePostUserNotesCount(post, count) {
  post.user_custom_fields ||= {};
  post.user_custom_fields.user_notes_count = count;
}
