export default function has(
  set: { has(item: unknown): boolean },
  item: unknown
): boolean {
  return set.has(item);
}
