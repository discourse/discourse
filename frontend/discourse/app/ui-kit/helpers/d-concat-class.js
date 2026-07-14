export default function dConcatClass(...args) {
  const classes = args.flat().filter(Boolean).join(" ");

  if (classes.length) {
    return classes;
  }
}
