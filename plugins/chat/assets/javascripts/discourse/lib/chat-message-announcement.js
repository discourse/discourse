import { isImage } from "discourse/lib/uploads";
import { i18n } from "discourse-i18n";

// strip tags AND decode entities, so the screen reader doesn't read literal "&amp;" / "&hellip;"
function bodyText(message) {
  const text = message.excerpt || message.message || "";
  const parsed = new DOMParser().parseFromString(text, "text/html");
  return (parsed.body.textContent || "").replace(/\s+/g, " ").trim();
}

export function messageAnnouncementText(message) {
  const username = message.user?.username;
  const uploads = message.uploads ?? [];

  if (uploads.length > 0) {
    const count = uploads.length;
    const isImages = uploads.every((upload) =>
      isImage(upload.original_filename)
    );

    const caption = (message.message || "").trim() ? bodyText(message) : "";

    if (caption) {
      return i18n(
        isImages
          ? "chat.screen_reader.new_message_with_image"
          : "chat.screen_reader.new_message_with_attachment",
        { username, message: caption, count }
      );
    }

    return i18n(
      isImages
        ? "chat.screen_reader.new_image"
        : "chat.screen_reader.new_attachment",
      { username, count }
    );
  }

  return i18n("chat.screen_reader.new_message", {
    username,
    message: bodyText(message),
  });
}
