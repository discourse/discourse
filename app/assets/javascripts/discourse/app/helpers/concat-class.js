export default function concatClass(...args) {
  const classes = args.compact().join(" ");

  if (classes.length) {
    return classes;
  }
}
