"use strict";

const fs = require("node:fs");
const {
  DeprecationStackResolver,
  parseStack,
} = require("./deprecation-report");

function resolveMessages(messages) {
  const resolver = new DeprecationStackResolver();
  return messages.map((message) =>
    message
      .split("\n")
      .flatMap((line) => {
        const [frame] = parseStack(line);
        if (!frame) {
          return [line];
        }

        const original = resolver.resolveFrame(frame);
        if (!original.resolved || original.approximate) {
          return [line];
        }

        const location = `${original.file}:${original.line}:${original.column}`;
        return [
          `    at ${frame.fn ? `${frame.fn} (${location})` : location}`,
          ...(original.code ? [`        ${original.code}`] : []),
        ];
      })
      .join("\n")
  );
}

const messages = JSON.parse(fs.readFileSync(0, "utf8"));
process.stdout.write(JSON.stringify(resolveMessages(messages)));
