import storePretender from 'helpers/store-pretender';
import fixturePretender from 'helpers/fixture-pretender';

function parsePostData(query) {
  const result = {};
  query.split("&").forEach(function(part) {
    const item = part.split("=");
    const firstSeg = decodeURIComponent(item[0]);
    const m = /^([^\[]+)\[([^\]]+)\]/.exec(firstSeg);

    const val = decodeURIComponent(item[1]).replace(/\+/g, ' ');
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
  return [code, {"Content-Type": "application/json"}, obj];
}

const success = () => response({ success: true });
const loggedIn = () => !!Discourse.User.current();


const helpers = { response, success, parsePostData };

export default function() {

  const server = new Pretender(function() {
    storePretender.call(this, helpers);
    const fixturesByUrl = fixturePretender.call(this, helpers);

    this.get('/admin/plugins', () => response({ plugins: [] }));

    this.get('/composer-messages', () => response([]));

    this.get("/latest.json", () => {
      const json = fixturesByUrl['/latest.json'];

      if (loggedIn()) {
        // Stuff to let us post
        json.topic_list.can_create_topic = true;
        json.topic_list.draft_key = "new_topic";
        json.topic_list.draft_sequence = 1;
      }
      return response(json);
    });

    this.get('/users/eviltrout.json', () => {
      const json = fixturesByUrl['/users/eviltrout.json'];
      if (loggedIn()) {
        json.user.can_edit = true;
      }
      return response(json);
    });

    this.put('/users/eviltrout', () => response({ user: {} }));

    this.get("/t/280.json", () => response(fixturesByUrl['/t/280/1.json']));

    this.get("/t/28830.json", () => response(fixturesByUrl['/t/28830/1.json']));

    this.get("/t/9.json", () => response(fixturesByUrl['/t/9/1.json']));

    this.get("/t/id_for/:slug", () => {
      return response({id: 280, slug: "internationalization-localization", url: "/t/internationalization-localization/280"});
    });

    this.get("/404-body", () => {
      return [200, {"Content-Type": "text/html"}, "<div class='page-not-found'>not found</div>"];
    });

    this.delete('/draft.json', success);
    this.post('/draft.json', success);

    this.get('/users/:username/staff-info.json', () => response({}));

    this.get('/post_action_users', () => {
      return response({
        post_action_users: [
           {id: 1, username: 'eviltrout', avatar_template: '/user_avatar/default/eviltrout/{size}/1.png', username_lower: 'eviltrout' }
         ]
      });
    });

    this.get('/post_replies', () => {
      return response({ post_replies: [{ id: 1234, cooked: 'wat' }] });
    });

    this.get('/post_reply_histories', () => {
      return response({ post_reply_histories: [{ id: 1234, cooked: 'wat' }] });
    });

    this.put('/categories/:category_id', request => {
      const category = parsePostData(request.requestBody);
      return response({category});
    });

    this.get('/draft.json', () => response({}));

    this.put('/queued_posts/:queued_post_id', function(request) {
      return response({ queued_post: {id: request.params.queued_post_id } });
    });

    this.get('/queued_posts', function() {
      return response({
        queued_posts: [{id: 1, raw: 'queued post text', can_delete_user: true}]
      });
    });

    this.post('/session', function(request) {
      const data = parsePostData(request.requestBody);

      if (data.password === 'correct') {
        return response({username: 'eviltrout'});
      }
      return response(400, {error: 'invalid login'});
    });

    this.get('/users/hp.json', function() {
      return response({"value":"32faff1b1ef1ac3","challenge":"61a3de0ccf086fb9604b76e884d75801"});
    });

    this.get('/session/csrf', function() {
      return response({"csrf":"mgk906YLagHo2gOgM1ddYjAN4hQolBdJCqlY6jYzAYs="});
    });

    this.get('/users/check_username', function(request) {
      if (request.queryParams.username === 'taken') {
        return response({available: false, suggestion: 'nottaken'});
      }
      return response({available: true});
    });

    this.post('/users', () => response({success: true}));

    this.get('/login.html', () => [200, {}, 'LOGIN PAGE']);

    this.delete('/posts/:post_id', success);
    this.put('/posts/:post_id/recover', success);
    this.get('/posts/:post_id/expand-embed', success);

    this.put('/posts/:post_id', request => {
      const data = parsePostData(request.requestBody);
      data.post.id = request.params.post_id;
      data.post.version = 2;
      return response(200, data.post);
    });

    this.get('/t/403.json', () => response(403, {}));
    this.get('/t/404.json', () => response(404, "not found"));
    this.get('/t/500.json', () => response(502, {}));

    this.put('/t/:slug/:id', request => {
      const data = parsePostData(request.requestBody);

      return response(200, { basic_topic: {id: request.params.id,
                                           title: data.title,
                                           fancy_title: data.title,
                                           slug: request.params.slug } });
    });

    this.get("/groups/discourse/topics.json", () => {
      return response(200, fixturesByUrl['/groups/discourse/posts.json']);
    });

    this.get("/groups/discourse/mentions.json", () => {
      return response(200, fixturesByUrl['/groups/discourse/posts.json']);
    });

    this.get("/groups/discourse/messages.json", () => {
      return response(200, fixturesByUrl['/groups/discourse/posts.json']);
    });

    this.get('/t/:topic_id/posts.json', request => {
      const postIds = request.queryParams.post_ids;
      const posts = postIds.map(p => ({id: parseInt(p), post_number: parseInt(p) }));
      return response(200, { post_stream: { posts } });
    });

    this.get('/posts/:post_id/reply-history.json', () => {
      return response(200, [ { id: 2222, post_number: 2222 } ]);
    });

    this.post('/posts', function(request) {
      const data = parsePostData(request.requestBody);

      if (data.title === "this title triggers an error") {
        return response(422, {errors: ['That title has already been taken']});
      }

      if (data.raw === "enqueue this content please") {
        return response(200, { success: true, action: 'enqueued' });
      }

      return response(200, {
        success: true,
        action: 'create_post',
        post: {id: 12345, topic_id: 280, topic_slug: 'internationalization-localization'}
      });
    });

    this.post('/topics/timings', () => response(200, {}));

    const siteText = {id: 'site.test', value: 'Test McTest'};
    const overridden = {id: 'site.overridden', value: 'Overridden', overridden: true };
    this.get('/admin/customize/site_texts', request => {

      if (request.queryParams.overridden) {
        return response(200, {site_texts: [overridden] });
      } else {
        return response(200, {site_texts: [siteText, overridden] });
      }
    });

    this.get('/admin/customize/site_texts/:key', () => response(200, {site_text: siteText }));
    this.delete('/admin/customize/site_texts/:key', () => response(200, {site_text: siteText }));

    this.put('/admin/customize/site_texts/:key', request => {
      const result = parsePostData(request.requestBody);
      result.id = request.params.key;
      result.can_revert = true;
      return response(200, {site_text: result});
    });
  });

  server.prepareBody = function(body){
    if (body && typeof body === "object") {
      return JSON.stringify(body);
    }
    return body;
  };

  server.unhandledRequest = function(verb, path) {
    const error = 'Unhandled request in test environment: ' + path + ' (' + verb + ')';
    window.console.error(error);
    throw error;
  };

  server.checkPassthrough = request => request.requestHeaders['Discourse-Script'];
  return server;
}
