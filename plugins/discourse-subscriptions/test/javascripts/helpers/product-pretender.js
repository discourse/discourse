export default function (helpers) {
  const { response } = helpers;

  this.get("/s", () => {
    const products = [
      {
        id: "prod_23o8I7tU4g56",
        name: "Awesome Product",
        description:
          "Subscribe to our awesome product. For only $230.10 per month, you can get access. This is a test site. No real credit card transactions.",
      },
      {
        id: "prod_B23dc9I7tU4eCy",
        name: "Special Product",
        description:
          "This is another subscription product. You can have more than one. From $12 per month.",
      },
    ];

    return response(products);
  });

  this.get("/s/:id", () => {
    const product = {
      id: "prod_23o8I7tU4g56",
      name: "Awesome Product",
      description:
        "Subscribe to our awesome product. For only $230.10 per month, you can get access. This is a test site. No real credit card transactions.",
    };
    const plans = [
      {
        id: "plan_GHGHSHS8654G",
        amount: 200,
        currency: "usd",
        interval: "month",
      },
    ];

    return response({ product, plans });
  });
}
