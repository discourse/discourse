import { helper } from "@ember/component/helper";

function concatClass(args) {
  const classes = args.compact().join(" ");
  return classes.length ? classes : undefined;
}

export default helper(concatClass);
