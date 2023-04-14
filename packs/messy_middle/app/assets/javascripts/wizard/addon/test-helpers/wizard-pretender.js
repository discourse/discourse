export default function (helpers) {
  const { parsePostData, response } = helpers;

  this.get("/wizard.json", () => {
    return response({
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
                description: "Your name",
              },
            ],
            next: "styling",
          },
          {
            id: "styling",
            title: "Second step",
            index: 1,
            fields: [{ id: "some_title", type: "text" }],
            previous: "hello-world",
            next: "corporate",
          },
          {
            id: "corporate",
            index: 2,
            fields: [
              { id: "company_name", type: "text", required: true },
              { id: "styling_preview", type: "component" },
            ],
            previous: "styling",
          },
        ],
      },
    });
  });

  this.put("/wizard/steps/:id", (request) => {
    const body = parsePostData(request.requestBody);

    if (body.fields.full_name === "Server Fail") {
      return response(422, {
        errors: [{ field: "full_name", description: "Invalid name" }],
      });
    } else if (body.fields.company_name === "Server Fail") {
      return response(422, {
        errors: [
          { field: "company_name", description: "Invalid company name" },
        ],
      });
    } else {
      return response(200, { success: true });
    }
  });
}
