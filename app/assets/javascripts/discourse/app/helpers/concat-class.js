export default function concatClass(...args) {
  const classes = args.flat().filter(Boolean).join(" ");

  if (classes.length) {
    return classes;
  }
}
