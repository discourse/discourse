/**
 * Tool API Quick Reference
 *
 * Entry Functions
 *
 * invoke(parameters): Main function. Receives parameters defined in the tool's signature (Object).
 *                    Must return a JSON-serializable value (e.g., string, number, object, array).
 * Example:
 *   function invoke(parameters) { return { result: "Data processed", input: parameters.query }; }
 *
 * details(): Optional function. Returns a string (can include basic HTML) describing
 *            the tool's action after invocation, often using data from the invocation.
 *            This is displayed in the chat interface.
 * Example:
 *   let lastUrl;
 *   function invoke(parameters) {
 *     lastUrl = parameters.url;
 *     // ... perform action ...
 *     return { success: true, content: "..." };
 *   }
 *   function details() {
 *     return `Browsed: <a href="${lastUrl}">${lastUrl}</a>`;
 *   }
 *
 * Provided Objects & Functions
 *
 * 1. http
 *    Performs HTTP requests. Max 20 requests per execution.
 *
 *    http.get(url, options?): Performs GET request.
 *    Parameters:
 *      url (string): The request URL.
 *      options (Object, optional):
 *        headers (Object): Request headers (e.g., { "Authorization": "Bearer key" }).
 *    Returns: { status: number, body: string }
 *
 *    http.post(url, options?): Performs POST request.
 *    Parameters:
 *      url (string): The request URL.
 *      options (Object, optional):
 *        headers (Object): Request headers.
 *        body (string | Object): Request body. If an object, it's stringified as JSON.
 *    Returns: { status: number, body: string }
 *
 *    http.put(url, options?): Performs PUT request (similar to POST).
 *    http.patch(url, options?): Performs PATCH request (similar to POST).
 *    http.delete(url, options?): Performs DELETE request (similar to GET/POST).
 *
 * 2. llm
 *    Interacts with the Language Model.
 *
 *    llm.truncate(text, length): Truncates text to a specified token length based on the configured LLM's tokenizer.
 *    Parameters:
 *      text (string): Text to truncate.
 *      length (number): Maximum number of tokens.
 *    Returns: string (truncated text)
 *
 *    llm.generate(prompt, options?): Generates text using the configured LLM associated with the tool runner.
 *    Parameters:
 *      prompt (string | Object): The prompt. Can be a simple string or an object
 *                                like { messages: [{ type: "system", content: "..." }, { type: "user", content: "..." }] }.
 *      options (Object, optional):
 *        json (boolean): If true, requests JSON output from the LLM and automatically parses it.
 *    Returns: string | Object (generated text or parsed JSON)
 *
 * 3. index
 *    Searches attached RAG (Retrieval-Augmented Generation) documents linked to this tool.
 *
 *    index.search(query, options?): Searches indexed document fragments.
 *    Parameters:
 *      query (string): The search query used for semantic search.
 *      options (Object, optional):
 *        filenames (Array<string>): Filter search to fragments from specific uploaded filenames.
 *        limit (number): Maximum number of fragments to return (default: 10, max: 200).
 *    Returns: Array<{ fragment: string, metadata: string | null }> - Ordered by relevance.
 *
 * 4. upload
 *    Handles file uploads within Discourse.
 *
 *    upload.create(filename, base_64_content): Uploads a file created by the tool, making it available in Discourse.
 *    Parameters:
 *      filename (string): The desired name for the file (basename is used for security).
 *      base_64_content (string): Base64 encoded content of the file.
 *    Returns: { id: number, url: string, short_url: string } - Details of the created upload record.
 *
 *    upload.getUrl(shortUrl): Given a short URL, eg upload://12345, returns the full CDN friendly URL of the upload.
 *
 *    upload.getBase64(uploadIdOrShortUrl, maxPixels): Fetches the base64-encoded content of an existing upload.
 *    Parameters:
 *      uploadIdOrShortUrl (number | string): Either an upload ID (number) or short URL (string, eg "upload://abc123").
 *      maxPixels (number, optional): Maximum pixel count for automatic resizing (default: 10,000,000).
 *    Returns: string (base64-encoded image data) or null if upload not found.
 *    Use case: Image editing tools can fetch existing uploads to send to external APIs.
 *
 *    Note for Image Editing:
 *    To implement image editing in a tool:
 *    1. Accept an `image_urls` parameter (array of short URLs like ["upload://abc123"]).
 *    2. Use upload.getBase64() to fetch the base64 data for each image.
 *    3. Send the base64 data to your image editing API (e.g., OpenAI's /v1/images/edits endpoint).
 *    4. Create a new upload with the edited image using upload.create().
 *    5. Use chain.setCustomRaw() to display the edited image.
 * 5. chain
 *    Controls the execution flow.
 *
 *    chain.setCustomRaw(raw): Sets the final raw content of the bot's post and immediately
 *                             stops the tool execution chain. Useful for tools that directly
 *                             generate the full response content (e.g., image generation tools attaching the image markdown).
 *    Parameters:
 *      raw (string): The raw Markdown content for the post.
 *    Returns: void
 *
 * 6. discourse
 *    Interacts with Discourse specific features. Access is generally performed as the SystemUser.
 *
 *    discourse.baseUrl: The base URL of the Discourse site (e.g., "https://meta.discourse.org").
 *
 *    discourse.search(params): Performs a Discourse search.
 *    Parameters:
 *      params (Object): Search parameters (e.g., { search_query: "keyword", with_private: true, max_results: 10 }).
 *                       `with_private: true` searches across all posts visible to the SystemUser. `result_style: 'detailed'` is used by default.
 *    Returns: Object (Discourse search results structure, includes posts, topics, users etc.)
 *
 *    discourse.getPost(post_id): Retrieves details for a specific post.
 *    Parameters:
 *      post_id (number): The ID of the post.
 *    Returns: Object (Post details including `raw`, nested `topic` object with ListableTopicSerializer structure) or null if not found/accessible.
 *
 *    discourse.getTopic(topic_id): Retrieves details for a specific topic.
 *    Parameters:
 *      topic_id (number): The ID of the topic.
 *    Returns: Object (Topic details using ListableTopicSerializer structure, plus `tags`, `first_post_id`,
 *             `category_id`, `category_name`, `category_slug`) or null if not found/accessible.
 *
 *    discourse.getUser(user_id_or_username): Retrieves details for a specific user.
 *    Parameters:
 *      user_id_or_username (number | string): The ID or username of the user.
 *    Returns: Object (User details using UserSerializer structure) or null if not found.
 *
 *    discourse.getPersona(name): Gets an object representing another AI Persona configured on the site.
 *    Parameters:
 *      name (string): The name of the target persona.
 *    Returns: Object { respondTo: function(params) } or null if persona not found.
 *      respondTo(params): Instructs the target persona to generate a response within the current context (e.g., replying to the same post or chat message).
 *      Parameters:
 *        params (Object, optional): { instructions: string, whisper: boolean }
 *      Returns: { success: boolean, post_id?: number, post_number?: number, message_id?: number } or { error: string }
 *
 *    discourse.createChatMessage(params): Creates a new message in a Discourse Chat channel.
 *    Parameters:
 *      params (Object): { channel_name: string, username: string, message: string }
 *                       `channel_name` can be the channel name or slug.
 *                       `username` specifies the user who should appear as the sender. The user must exist.
 *                       The sending user must have permission to post in the channel.
 *    Returns: { success: boolean, message_id?: number, message?: string, created_at?: string } or { error: string }
 *
 *    discourse.editTopic(topic_id, updates, options?): Edits topic properties (tags, category, visibility).
 *    Parameters:
 *      topic_id (number): The ID of the topic.
 *      updates (Object): Properties to update (all optional):
 *        tags (Array<string>): Tags to apply to the topic.
 *        category (number | string): Category ID, name, or slug.
 *        visible (boolean): true to list, false to unlist.
 *      options (Object, optional):
 *        username (string): The username of the user performing the action.
 *        silent (boolean): Skip notifications for category changes (default: false).
 *        append (boolean): Append tags instead of replacing (default: false).
 *    Returns: { success: boolean, topic: { id, category_id, category_name, category_slug, tags, visible, visibility_reason_id } }
 *    Throws: Error if topic not found, permission denied, or operation fails.
 *    Note: `discourse.setTags(topic_id, tags, options)` is available as a backwards-compatible alias.
 *
 *    discourse.editPost(post_id, raw, options?): Edits a post's content.
 *    Parameters:
 *      post_id (number): The ID of the post.
 *      raw (string): The new raw Markdown content.
 *      options (Object, optional):
 *        edit_reason (string): Reason for the edit.
 *        username (string): The username of the user performing the action.
 *    Returns: { success: boolean, post_id: number }
 *
 * 7. context
 *    An object containing information about the environment where the tool is being run.
 *    Available properties depend on the invocation context, but may include:
 *      post_id (number): ID of the post triggering the tool (if in a Post context).
 *      topic_id (number): ID of the topic (if in a Post context).
 *      private_message (boolean): Whether the context is a private message (in Post context).
 *      message_id (number): ID of the chat message triggering the tool (if in Chat context).
 *      channel_id (number): ID of the chat channel (if in Chat context).
 *      user (Object): Details of the user invoking the tool/persona (structure may vary, often null or SystemUser details unless explicitly passed).
 *      participants (string): Comma-separated list of usernames in a PM (if applicable).
 *      // ... other potential context-specific properties added by the calling environment.
 *
 * Constraints
 *
 * Execution Time: ≤ 2000ms (default timeout in milliseconds) - This timer *pauses* during external HTTP requests or LLM calls initiated via `http.*` or `llm.generate`, but applies to the script's own processing time.
 * Memory: ≤ 10MB (V8 heap limit)
 * Stack Depth: ≤ 20 (Marshal stack depth limit for Ruby interop)
 * HTTP Requests: ≤ 20 per execution
 * Exceeding limits will result in errors or termination (e.g., timeout error, out-of-memory error, TooManyRequestsError).
 *
 * Security
 *
 * Sandboxed Environment: The script runs in a restricted V8 JavaScript environment (via MiniRacer).
 * No direct access to browser or environment, browser globals (like `window` or `document`), or the host system's file system.
 * Network requests are proxied through the Discourse backend, not made directly from the sandbox.
 */
