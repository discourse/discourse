export const SEPARATOR = ":";

export function replaceSpan($elem, categorySlug, categoryLink) {
  $elem.replaceWith(`<a href="${categoryLink}" class="hashtag">#<span>${categorySlug}</span></a>`);
};
