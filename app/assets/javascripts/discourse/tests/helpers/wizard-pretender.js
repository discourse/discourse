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
            next: "hello-again",
          },
          {
            id: "hello-again",
            title: "hello again",
            index: 1,
            fields: [
              {
                id: "nick_name",
                type: "text",
                required: false,
                description: "Your nick name",
              },
            ],
            previous: "hello-world",
            next: "ready",
          },
          {
            id: "ready",
            title: "your site is ready",
            index: 2,
            fields: [],
            previous: "hello-again",
            next: "optional",
          },
          {
            id: "optional",
            title: "Optional step",
            index: 3,
            fields: [{ id: "some_title", type: "text" }],
            previous: "ready",
            next: "corporate",
          },
          {
            id: "corporate",
            index: 4,
            fields: [
              { id: "company_name", type: "text", required: true },
              { id: "styling_preview", type: "styling-preview" },
            ],
            previous: "optional",
          },
        ],
      },
    });
  });

  this.put("/wizard/steps/:id", (request) => {
    const body = parsePostData(request.requestBody);

    if (body.fields?.full_name === "Server Fail") {
      return response(422, {
        errors: [{ field: "full_name", description: "Invalid name" }],
      });
    } else if (body.fields?.company_name === "Server Fail") {
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
