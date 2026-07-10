export default function gte(
  left: unknown,
  right: unknown,
  { forceNumber = false }: { forceNumber?: boolean } = {}
): boolean {
  if (forceNumber) {
    if (typeof left !== "number") {
      left = Number(left);
    }
    if (typeof right !== "number") {
      right = Number(right);
    }
  }
  return (left as number) >= (right as number);
}
