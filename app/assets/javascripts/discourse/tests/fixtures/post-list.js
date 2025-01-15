const postModel = [
  {
    id: 1,
    title: "My dog is so cute",
    url: "/t/my-dog-is-so-cute/1/1",
    created_at: "2024-03-15T18:45:38.720Z",
    category: {
      id: 1,
      name: "Pets",
      color: "f00",
    },
    user: {
      id: 1,
      username: "uwe_keim",
      name: "Uwe Keim",
      avatar_template: "/user_avatar/meta.discourse.org/uwe_keim/{size}/5697.png"
    },
    cooked:
      "<p>I am really enjoying having a dog. My dog is so cute. He is a toy poodle, and he loves to play fetch.</p><p>He also loves to go outside to the dog park, eat treats, and take naps.</p>",
    excerpt: "<p>I am really enjoying having a dog. My dog is so cute. He is a toy poodle...</p>",
  },
  {
    id: 2,
    title: "My cat is adorable",
    url: "/t/my-cat-is-so-adorable/2/1",
    created_at: "2024-03-16T18:45:38.720Z",
    category: {
      id: 1,
      name: "Pets",
      color: "f00",
    },
    user: {
      id: 1,
      username: "uwe_keim",
      name: "Uwe Keim",
      avatar_template: "/user_avatar/meta.discourse.org/uwe_keim/{size}/5697.png"
    },
    cooked:
      "<p>I am really enjoying having a cat. My cat is so cute. She loves to cuddle.</p><p>She also loves to go wander the neighbourhood.</p>",
    excerpt: "<p>I am really enjoying having a cat. My cat is so cute...</p>",
  },
];

export default postModel;
