export default function includes(
  array: { includes(item: unknown): boolean },
  item: unknown
): boolean {
  return array.includes(item);
}
