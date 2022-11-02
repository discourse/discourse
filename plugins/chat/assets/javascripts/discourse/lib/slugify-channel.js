import { slugify } from "discourse/lib/utilities";

export default function slugifyChannel(title) {
  const slug = slugify(title);
  return (
    slug.length ? slug : title.trim().toLowerCase().replace(/\s|_+/g, "-")
  ).slice(0, 100);
}
