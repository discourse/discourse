export const SEPARATOR = ":";

export function replaceSpan($elem, categorySlug, categoryLink, type) {
  type = type ? ` data-type="${type}"` : "";
  $elem.replaceWith(
    `<a href="${categoryLink}" class="hashtag"${type}>#<span>${categorySlug}</span></a>`
  );
}
