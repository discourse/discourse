# frozen_string_literal: true

class AiTool < ActiveRecord::Base
  validates :name, presence: true, length: { maximum: 100 }, uniqueness: true
  validates :tool_name, presence: true, length: { maximum: 100 }
  validates :description, presence: true, length: { maximum: 1000 }
  validates :summary, presence: true, length: { maximum: 255 }
  validates :script, presence: true, length: { maximum: 100_000 }
  validates :created_by_id, presence: true
  belongs_to :created_by, class_name: "User"
  belongs_to :rag_llm_model, class_name: "LlmModel"
  has_many :rag_document_fragments, dependent: :destroy, as: :target
  has_many :upload_references, as: :target, dependent: :destroy
  has_many :uploads, through: :upload_references
  before_update :regenerate_rag_fragments

  ALPHANUMERIC_PATTERN = /\A[a-zA-Z0-9_]+\z/

  validates :tool_name,
            format: {
              with: ALPHANUMERIC_PATTERN,
              message: I18n.t("discourse_ai.tools.name.characters"),
            }

  validate :validate_parameters_enum

  def signature
    {
      name: function_call_name,
      description: description,
      parameters: parameters.map(&:symbolize_keys),
    }
  end

  # Backwards compatibility: if tool_name is not set (existing custom tools), use name
  def function_call_name
    tool_name.presence || name
  end

  def runner(parameters, llm:, bot_user:, context: nil)
    DiscourseAi::Personas::ToolRunner.new(
      parameters: parameters,
      llm: llm,
      bot_user: bot_user,
      context: context,
      tool: self,
    )
  end

  after_commit :bump_persona_cache

  def bump_persona_cache
    AiPersona.persona_cache.flush!
  end

  def regenerate_rag_fragments
    if rag_chunk_tokens_changed? || rag_chunk_overlap_tokens_changed?
      RagDocumentFragment.where(target: self).delete_all
    end
  end

  def validate_parameters_enum
    return unless parameters.is_a?(Array)

    parameters.each_with_index do |param, index|
      next if !param.is_a?(Hash) || !param.key?("enum")
      enum_values = param["enum"]

      if enum_values.empty?
        errors.add(
          :parameters,
          "Parameter '#{param["name"]}' at index #{index}: enum cannot be empty",
        )
        next
      end

      if enum_values.uniq.length != enum_values.length
        errors.add(
          :parameters,
          "Parameter '#{param["name"]}' at index #{index}: enum values must be unique",
        )
      end
    end
  end

  def self.preamble
    <<~JS
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
     *    llm.generate(prompt): Generates text using the configured LLM associated with the tool runner.
     *    Parameters:
     *      prompt (string | Object): The prompt. Can be a simple string or an object
     *                                like { messages: [{ type: "system", content: "..." }, { type: "user", content: "..." }] }.
     *    Returns: string (generated text)
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
     *    Returns: Object (Topic details using ListableTopicSerializer structure) or null if not found/accessible.
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
    JS
  end

  def self.presets
    [
      {
        preset_id: "browse_web_jina",
        name: "Browse Web",
        tool_name: "browse_web",
        description: "Browse the web as a markdown document",
        parameters: [
          { name: "url", type: "string", required: true, description: "The URL to browse" },
        ],
        script: <<~SCRIPT,
          #{preamble}
          let url;
          function invoke(p) {
              url = p.url;
              result = http.get(`https://r.jina.ai/${url}`);
              // truncates to 15000 tokens
              return llm.truncate(result.body, 15000);
          }
          function details() {
            return "Read: " + url
          }
        SCRIPT
      },
      {
        preset_id: "exchange_rate",
        name: "Exchange Rate",
        tool_name: "exchange_rate",
        description: "Get current exchange rates for various currencies",
        parameters: [
          {
            name: "base_currency",
            type: "string",
            required: true,
            description: "The base currency code (e.g., USD, EUR)",
          },
          {
            name: "target_currency",
            type: "string",
            required: true,
            description: "The target currency code (e.g., EUR, JPY)",
          },
          { name: "amount", type: "number", description: "Amount to convert eg: 123.45" },
        ],
        script: <<~SCRIPT,
        #{preamble}
        // note: this script uses the open.er-api.com service, it is only updated
        // once every 24 hours, for more up to date rates see: https://www.exchangerate-api.com
        function invoke(params) {
          const url = `https://open.er-api.com/v6/latest/${params.base_currency}`;
          const result = http.get(url);
          if (result.status !== 200) {
            return { error: "Failed to fetch exchange rates" };
          }
          const data = JSON.parse(result.body);
          const rate = data.rates[params.target_currency];
          if (!rate) {
            return { error: "Target currency not found" };
          }

          const rval = {
            base_currency: params.base_currency,
            target_currency: params.target_currency,
            exchange_rate: rate,
            last_updated: data.time_last_update_utc
          };

          if (params.amount) {
            rval.original_amount = params.amount;
            rval.converted_amount = params.amount * rate;
          }

          return rval;
        }

        function details() {
          return "<a href='https://www.exchangerate-api.com'>Rates By Exchange Rate API</a>";
        }
      SCRIPT
        summary: "Get current exchange rates between two currencies",
      },
      {
        preset_id: "stock_quote",
        name: "Stock Quote (AlphaVantage)",
        tool_name: "stock_quote",
        description: "Get real-time stock quote information using AlphaVantage API",
        parameters: [
          {
            name: "symbol",
            type: "string",
            required: true,
            description: "The stock symbol (e.g., AAPL, GOOGL)",
          },
        ],
        script: <<~SCRIPT,
        #{preamble}
        function invoke(params) {
          const apiKey = 'YOUR_ALPHAVANTAGE_API_KEY'; // Replace with your actual API key
          const url = `https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=${params.symbol}&apikey=${apiKey}`;

          const result = http.get(url);
          if (result.status !== 200) {
            return { error: "Failed to fetch stock quote" };
          }

          const data = JSON.parse(result.body);
          if (data['Error Message']) {
            return { error: data['Error Message'] };
          }

          const quote = data['Global Quote'];
          if (!quote || Object.keys(quote).length === 0) {
            return { error: "No data found for the given symbol" };
          }

          return {
            symbol: quote['01. symbol'],
            price: parseFloat(quote['05. price']),
            change: parseFloat(quote['09. change']),
            change_percent: quote['10. change percent'],
            volume: parseInt(quote['06. volume']),
            latest_trading_day: quote['07. latest trading day']
          };
        }

        function details() {
          return "<a href='https://www.alphavantage.co'>Stock data provided by AlphaVantage</a>";
        }
      SCRIPT
        summary: "Get real-time stock quotes using AlphaVantage API",
      },
      {
        preset_id: "image_generation",
        name: "Image Generation (Flux)",
        tool_name: "image_generation",
        description:
          "Generate images using the FLUX model from Black Forest Labs using together.ai",
        parameters: [
          {
            name: "prompt",
            type: "string",
            required: true,
            description: "The text prompt for image generation",
          },
          {
            name: "seed",
            type: "number",
            required: false,
            description: "Optional seed for random number generation",
          },
        ],
        script: <<~SCRIPT,
          #{preamble}
          const apiKey = "YOUR_KEY";
          const model = "black-forest-labs/FLUX.1.1-pro";

          function invoke(params) {
            let seed = parseInt(params.seed);
            if (!(seed > 0)) {
              seed = Math.floor(Math.random() * 1000000) + 1;
            }

            const prompt = params.prompt;
            const body = {
              model: model,
              prompt: prompt,
              width: 1024,
              height: 768,
              steps: 10,
              n: 1,
              seed: seed,
              response_format: "b64_json",
            };

            const result = http.post("https://api.together.xyz/v1/images/generations", {
              headers: {
                "Authorization": `Bearer ${apiKey}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify(body),
            });

            const base64Image = JSON.parse(result.body).data[0].b64_json;
            const image = upload.create("generated_image.png", base64Image);
            const raw = `\n![${prompt}](${image.short_url})\n`;
            chain.setCustomRaw(raw);

            return { result: "Image generated successfully", seed: seed };
          }

          function details() {
            return "Generates images based on a text prompt using the FLUX model.";
          }
  SCRIPT
        summary: "Generate image",
      },
      { preset_id: "empty_tool", script: <<~SCRIPT },
          #{preamble}
          function invoke(params) {
            // logic here
            return params;
          }
          function details() {
            return "Details about this tool";
          }
        SCRIPT
    ].map do |preset|
      preset[:preset_name] = I18n.t("discourse_ai.tools.presets.#{preset[:preset_id]}.name")
      preset
    end
  end
end

# == Schema Information
#
# Table name: ai_tools
#
#  id                       :bigint           not null, primary key
#  description              :string           not null
#  enabled                  :boolean          default(TRUE), not null
#  name                     :string           not null
#  parameters               :jsonb            not null
#  rag_chunk_overlap_tokens :integer          default(10), not null
#  rag_chunk_tokens         :integer          default(374), not null
#  script                   :text             not null
#  summary                  :string           not null
#  tool_name                :string(100)      default(""), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  created_by_id            :integer          not null
#  rag_llm_model_id         :bigint
#
