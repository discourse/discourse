export default function configureTestFilter(config, queryParams) {
  const mode = queryParams.get("discourseTestFilterMode");
  if (!["literal", "regex"].includes(mode)) {
    return;
  }

  const filter = queryParams.get("filter");
  if (filter === null) {
    return;
  }

  config.filter = undefined;

  if (mode === "literal") {
    const normalizedLiteral = filter.toLowerCase();
    config.testFilter = ({ module, testName }) =>
      `${module}: ${testName}`.toLowerCase().includes(normalizedLiteral);
  } else if (mode === "regex") {
    let regex;
    try {
      regex = new RegExp(filter, "i");
    } catch (e) {
      throw new Error(
        `Invalid --filter-regex pattern: ${filter} (${e.message})`,
        {
          cause: e,
        }
      );
    }
    config.testFilter = ({ module, testName }) =>
      regex.test(`${module}: ${testName}`);
  }
}
