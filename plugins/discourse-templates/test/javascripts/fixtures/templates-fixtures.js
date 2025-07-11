export default {
  "/discourse_templates": {
    templates: [
      {
        id: 1,
        slug: "cupcake-ipsum-excerpt",
        title: "Cupcake Ipsum excerpt",
        content:
          "Cupcake ipsum dolor sit amet cotton candy cheesecake jelly. Candy canes sugar plum soufflé sweet roll jelly-o danish jelly muffin. I love jelly-o powder topping carrot cake toffee.",
        tags: ["cupcakes", "ipsum"],
        usages: 20,
      },
      {
        id: 2,
        slug: "hipster-ipsum-excerpt",
        title: "Hipster ipsum excerpt",
        content:
          "Qui butcher farm-to-table locavore sunt quinoa. Bicycle rights pariatur marfa etsy, four loko lomo veniam fashion axe aesthetic. Actually irony quis selfies readymade narwhal. Nesciunt pinterest cillum, wolf swag american apparel carles ex butcher non veniam.",
        tags: ["ipsum", "hipster"],
        usages: 7,
      },
      {
        id: 3,
        slug: "liquor-ipsum-excerpt",
        title: "Liquor ipsum excerpt",
        content:
          "Prince shnell hi-fi harper’s chupacabra; charro negro; tequila sunrise vodka mcgovern, glenlossie seven and seven gibbon matador singapore sling imperial. Quentão jagertee, port charlotte southern comfort pisco sour anisette glenlivet churchill sake bomb glenallachie brandy daisy?",
        tags: ["ipsum", "liquor"],
        usages: 3,
      },
      {
        id: 5,
        slug: "mussum-ipsum-excerpt",
        title: "Mussum Ipsum excerpt",
        content:
          "Mussum Ipsum, cacilds vidis litro abertis. Interagi no mé, cursus quis, vehicula ac nisi.A ordem dos tratores não altera o pão duris.Diuretics paradis num copo é motivis de denguis.Mais vale um bebadis conhecidiss, que um alcoolatra anonimis.",
        tags: ["ipsum", "mussum"],
        usages: 3,
      },
      {
        id: 6,
        slug: "my-first-template",
        title: "My first template",
        content:
          "This is an example template.\nYou can user **markdown** to style your replies. Click the **new** button to create new replies or the **edit** button to edit or remove an existing template.\n\n*This template will be added when the replies list is empty.*",
        tags: ["old-tests"],
        usages: 0,
      },
      {
        id: 7,
        slug: "testing",
        title: "Testing",
        content: "<script>alert('ahah')</script>",
        tags: ["old-tests", "scripts"],
        usages: 1,
      },
      {
        id: 8,
        slug: "this-is-a-test",
        title: "This is a test",
        content: "Testing testin **123**",
        tags: ["old-tests"],
        usages: 1,
      },
      {
        id: 9,
        slug: "using-variables-1",
        title: "Using variables (1)",
        content:
          "Hi %{reply_to_username,fallback:there}, regards %{my_username}.",
        tags: ["old-tests", "variables"],
        usages: 0,
      },
      {
        id: 10,
        slug: "using-variables-2",
        title: "Using variables (2)",
        content:
          "Hi %{reply_to_or_last_poster_username,fallback:there}, regards %{my_name}.",
        tags: ["old-tests", "variables"],
        usages: 0,
      },
      {
        id: 130,
        slug: "lorem-ipsum-dolor-sit-amet",
        title: "Lorem ipsum dolor sit amet",
        content:
          "\u003e **Lorem ipsum** dolor sit amet, consectetur adipiscing elit. Aenean ut tellus laoreet, mattis justo a, facilisis tellus. Curabitur purus arcu, auctor vel lobortis id, accumsan iaculis sapien. Duis aliquam libero velit, eget tincidunt turpis volutpat at. Nulla aliquet volutpat ipsum, non vehicula velit ultrices id. In hac habitasse platea dictumst. Proin eget mauris nec ligula interdum tincidunt nec nec diam. Pellentesque mauris lectus, sollicitudin ac libero sed, ornare volutpat ante. Maecenas ante dui, ultricies et odio id, consequat placerat dui. Sed vel magna ac neque luctus lacinia. Aenean diam massa, porttitor eget mi et, scelerisque maximus odio. Cras at mi augue. Maecenas efficitur augue a lectus auctor mattis. Aliquam non mauris in diam interdum semper a ac elit. Donec euismod justo in velit aliquet tempor. Nullam condimentum congue ligula, id vehicula purus malesuada vitae.",
        tags: ["lorem"],
        usages: 0,
      },
    ],
  },
};
