import { cook } from "discourse/lib/text";

export async function savePostRaw(post, raw, editReason) {
  const cooked = await cook(raw);

  return await post.save({
    raw,
    cooked: cooked.string,
    edit_reason: editReason,
  });
}
