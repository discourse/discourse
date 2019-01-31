// TODO: This file has some copied and pasted functions from `create-pretender` - would be good
// to centralize that code at some point.

function parsePostData(query) {
  const result = {};
  query.split("&").forEach(function(part) {
    const item = part.split("=");
    const firstSeg = decodeURIComponent(item[0]);
    const m = /^([^\[]+)\[([^\]]+)\]/.exec(firstSeg);

    const val = decodeURIComponent(item[1]).replace(/\+/g, " ");
    if (m) {
      result[m[1]] = result[m[1]] || {};
      result[m[1]][m[2]] = val;
    } else {
      result[firstSeg] = val;
    }
  });
  return result;
}

function response(code, obj) {
  if (typeof code === "object") {
    obj = code;
    code = 200;
  }
  return [code, { "Content-Type": "application/json" }, obj];
}

export default function() {
  const server = new Pretender(function() {
    this.get("/wizard.json", () => {
      return response(200, {
        wizard: {
          start: "hello-world",
          completed: true,
          steps: [
            {
              id: "hello-world",
              title: "hello there",
              index: 0,
              description: "hello!",
              fields: [
                {
                  id: "full_name",
                  type: "text",
                  required: true,
                  description: "Your name"
                }
              ],
              next: "second-step"
            },
            {
              id: "second-step",
              title: "Second step",
              index: 1,
              fields: [{ id: "some-title", type: "text" }],
              previous: "hello-world",
              next: "last-step"
            },
            {
              id: "last-step",
              index: 2,
              fields: [
                { id: "snack", type: "dropdown", required: true },
                { id: "theme-preview", type: "component" },
                { id: "an-image", type: "image" }
              ],
              previous: "second-step"
            }
          ]
        }
      });
    });

    this.put("/wizard/steps/:id", request => {
      const body = parsePostData(request.requestBody);

      if (body.fields.full_name === "Server Fail") {
        return response(422, {
          errors: [{ field: "full_name", description: "Invalid name" }]
        });
      } else {
        return response(200, { success: true });
      }
    });
  });

  server.prepareBody = function(body) {
    if (body && typeof body === "object") {
      return JSON.stringify(body);
    }
    return body;
  };

  server.unhandledRequest = function(verb, path) {
    const error =
      "Unhandled request in test environment: " + path + " (" + verb + ")";
    window.console.error(error);
    throw error;
  };

  return server;
}
