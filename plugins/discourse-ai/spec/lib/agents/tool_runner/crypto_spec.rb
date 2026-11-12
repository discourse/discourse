# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Agents::ToolRunner do
  def create_tool(script:)
    AiTool.create!(
      name: "test #{SecureRandom.uuid}",
      tool_name: "test_#{SecureRandom.uuid.underscore}",
      description: "test",
      parameters: [{ name: "query", type: "string", description: "perform a search" }],
      script: script,
      created_by_id: 1,
      summary: "Test tool summary",
    )
  end

  before { enable_current_plugin }

  describe "crypto operations" do
    describe "HMAC" do
      it "can compute HMAC-SHA256 hex digest" do
        tool =
          create_tool(
            script:
              'function invoke(params) { return crypto.hmacSha256("secret-key", "hello world"); }',
          )
        result = tool.runner({}, llm: nil, bot_user: nil).invoke
        expect(result).to eq(OpenSSL::HMAC.hexdigest("SHA256", "secret-key", "hello world"))
      end

      it "can compute HMAC-SHA1 hex digest" do
        tool =
          create_tool(
            script:
              'function invoke(params) { return crypto.hmacSha1("secret-key", "hello world"); }',
          )
        result = tool.runner({}, llm: nil, bot_user: nil).invoke
        expect(result).to eq(OpenSSL::HMAC.hexdigest("SHA1", "secret-key", "hello world"))
      end

      it "can compute HMAC-SHA256 base64 digest" do
        tool =
          create_tool(
            script:
              'function invoke(params) { return crypto.hmacSha256Base64("secret-key", "hello world"); }',
          )
        result = tool.runner({}, llm: nil, bot_user: nil).invoke
        expect(result).to eq(
          Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", "secret-key", "hello world")),
        )
      end

      it "can compute HMAC-SHA1 base64 digest" do
        tool =
          create_tool(
            script:
              'function invoke(params) { return crypto.hmacSha1Base64("secret-key", "hello world"); }',
          )
        result = tool.runner({}, llm: nil, bot_user: nil).invoke
        expect(result).to eq(
          Base64.strict_encode64(OpenSSL::HMAC.digest("SHA1", "secret-key", "hello world")),
        )
      end
    end

    describe "hashing" do
      it "can compute SHA256 hex digest" do
        tool =
          create_tool(script: 'function invoke(params) { return crypto.sha256("hello world"); }')
        result = tool.runner({}, llm: nil, bot_user: nil).invoke
        expect(result).to eq(Digest::SHA256.hexdigest("hello world"))
      end

      it "can compute SHA1 hex digest" do
        tool = create_tool(script: 'function invoke(params) { return crypto.sha1("hello world"); }')
        result = tool.runner({}, llm: nil, bot_user: nil).invoke
        expect(result).to eq(Digest::SHA1.hexdigest("hello world"))
      end

      it "can compute MD5 hex digest" do
        tool = create_tool(script: 'function invoke(params) { return crypto.md5("hello world"); }')
        result = tool.runner({}, llm: nil, bot_user: nil).invoke
        expect(result).to eq(Digest::MD5.hexdigest("hello world"))
      end

      it "can compute SHA256 base64 digest" do
        tool =
          create_tool(
            script: 'function invoke(params) { return crypto.sha256Base64("hello world"); }',
          )
        result = tool.runner({}, llm: nil, bot_user: nil).invoke
        expect(result).to eq(Base64.strict_encode64(Digest::SHA256.digest("hello world")))
      end

      it "can compute SHA1 base64 digest" do
        tool =
          create_tool(
            script: 'function invoke(params) { return crypto.sha1Base64("hello world"); }',
          )
        result = tool.runner({}, llm: nil, bot_user: nil).invoke
        expect(result).to eq(Base64.strict_encode64(Digest::SHA1.digest("hello world")))
      end

      it "can compute MD5 base64 digest" do
        tool =
          create_tool(script: 'function invoke(params) { return crypto.md5Base64("hello world"); }')
        result = tool.runner({}, llm: nil, bot_user: nil).invoke
        expect(result).to eq(Base64.strict_encode64(Digest::MD5.digest("hello world")))
      end
    end

    describe "base64 encoding" do
      it "can encode and decode base64" do
        script = <<~JS
          function invoke(params) {
            const encoded = crypto.base64Encode("Hello World!");
            const decoded = crypto.base64Decode(encoded);
            return { encoded: encoded, decoded: decoded };
          }
        JS

        tool = create_tool(script: script)
        result = tool.runner({}, llm: nil, bot_user: nil).invoke

        expect(result["encoded"]).to eq(Base64.strict_encode64("Hello World!"))
        expect(result["decoded"]).to eq("Hello World!")
      end

      it "produces url-safe base64 without padding" do
        # Build a Uint8Array with bytes whose standard base64 contains '+' and '/'
        # and needs padding. 0xfb 0xff 0xfe -> standard "+//+", urlsafe "-__-".
        script = <<~JS
          function invoke(params) {
            const bytes = new Uint8Array([0xfb, 0xff, 0xfe, 0xff]);
            return crypto.base64UrlEncode(bytes);
          }
        JS

        tool = create_tool(script: script)
        result = tool.runner({}, llm: nil, bot_user: nil).invoke
        expect(result).to eq(Base64.urlsafe_encode64("\xfb\xff\xfe\xff".b, padding: false))
        expect(result).not_to include("=")
        expect(result).not_to include("+")
        expect(result).not_to include("/")
      end

      it "round trips url-safe base64 through Uint8Array" do
        script = <<~JS
          function invoke(params) {
            const encoded = crypto.base64UrlEncode("héllo wörld");
            const decoded = crypto.base64UrlDecode(encoded);
            return {
              encoded: encoded,
              isUint8Array: decoded instanceof Uint8Array,
              length: decoded.length,
              reencoded: crypto.base64UrlEncode(decoded),
            };
          }
        JS

        tool = create_tool(script: script)
        result = tool.runner({}, llm: nil, bot_user: nil).invoke

        expect(result["isUint8Array"]).to eq(true)
        expect(result["encoded"]).to eq(Base64.urlsafe_encode64("héllo wörld", padding: false))
        expect(result["reencoded"]).to eq(result["encoded"])
      end

      it "accepts padded url-safe base64 input" do
        padded = Base64.urlsafe_encode64("abc") # "YWJj" (no padding needed) -> use different input
        padded = Base64.urlsafe_encode64("a") # "YQ=="
        script = <<~JS
          function invoke(params) {
            const decoded = crypto.base64UrlDecode(params.input);
            return String.fromCharCode.apply(null, Array.from(decoded));
          }
        JS

        tool = create_tool(script: script)
        result = tool.runner({ "input" => padded }, llm: nil, bot_user: nil).invoke
        expect(result).to eq("a")
      end
    end

    describe "byte-array variants" do
      it "returns Uint8Array for sha256Bytes and hmacSha256Bytes" do
        script = <<~JS
          function invoke(params) {
            const h = crypto.sha256Bytes("hello");
            const m = crypto.hmacSha256Bytes("k", "v");
            return {
              hashIsBytes: h instanceof Uint8Array,
              hashLen: h.length,
              hashMatches: crypto.base64Encode(h) === params.expectedHash,
              macMatches: crypto.base64Encode(m) === params.expectedMac,
            };
          }
        JS

        tool = create_tool(script: script)
        result =
          tool.runner(
            {
              "expectedHash" => Base64.strict_encode64(Digest::SHA256.digest("hello")),
              "expectedMac" => Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", "k", "v")),
            },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(result["hashIsBytes"]).to eq(true)
        expect(result["hashLen"]).to eq(32)
        expect(result["hashMatches"]).to eq(true)
        expect(result["macMatches"]).to eq(true)
      end
    end

    describe "RSA signing" do
      let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }

      it "signs data with RSA-SHA256 and the signature verifies" do
        script = <<~JS
          function invoke(params) {
            const sig = crypto.signRsaSha256(params.pem, params.data);
            return {
              isUint8Array: sig instanceof Uint8Array,
              length: sig.length,
              base64: crypto.base64Encode(sig),
            };
          }
        JS

        tool = create_tool(script: script)
        result =
          tool.runner(
            { "pem" => rsa_key.to_pem, "data" => "payload to sign" },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(result["isUint8Array"]).to eq(true)
        expect(result["length"]).to eq(256) # 2048-bit key

        signature = Base64.strict_decode64(result["base64"])
        expect(rsa_key.verify(OpenSSL::Digest.new("SHA256"), signature, "payload to sign")).to eq(
          true,
        )
      end

      it "produces a JWT that verifies with the public key" do
        script = <<~JS
          function invoke(params) {
            const header = crypto.base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
            const payload = crypto.base64UrlEncode(JSON.stringify({ sub: "42", iat: 1700000000 }));
            const signingInput = header + "." + payload;
            const sig = crypto.signRsaSha256(params.pem, signingInput);
            return signingInput + "." + crypto.base64UrlEncode(sig);
          }
        JS

        tool = create_tool(script: script)
        jwt = tool.runner({ "pem" => rsa_key.to_pem }, llm: nil, bot_user: nil).invoke

        header_b64, payload_b64, sig_b64 = jwt.split(".")
        signing_input = "#{header_b64}.#{payload_b64}"
        signature = Base64.urlsafe_decode64(sig_b64 + ("=" * ((4 - sig_b64.length % 4) % 4)))

        expect(rsa_key.verify(OpenSSL::Digest.new("SHA256"), signature, signing_input)).to eq(true)

        payload =
          JSON.parse(
            Base64.urlsafe_decode64(payload_b64 + ("=" * ((4 - payload_b64.length % 4) % 4))),
          )
        expect(payload).to eq({ "sub" => "42", "iat" => 1_700_000_000 })
      end

      it "raises a clear error when the key is not a valid RSA key" do
        script = <<~JS
          function invoke(params) {
            try {
              crypto.signRsaSha256("not a pem", "data");
              return { ok: true };
            } catch (e) {
              return { error: e.message };
            }
          }
        JS

        tool = create_tool(script: script)
        result = tool.runner({}, llm: nil, bot_user: nil).invoke
        expect(result["error"]).to include("Invalid RSA private key")
      end
    end

    describe "randomBytes" do
      it "returns a Uint8Array of the requested length" do
        script = <<~JS
          function invoke(params) {
            const a = crypto.randomBytes(16);
            const b = crypto.randomBytes(16);
            return {
              isUint8Array: a instanceof Uint8Array,
              length: a.length,
              differ: crypto.base64Encode(a) !== crypto.base64Encode(b),
            };
          }
        JS

        tool = create_tool(script: script)
        result = tool.runner({}, llm: nil, bot_user: nil).invoke
        expect(result["isUint8Array"]).to eq(true)
        expect(result["length"]).to eq(16)
        expect(result["differ"]).to eq(true)
      end

      it "rejects out-of-range lengths" do
        script = <<~JS
          function invoke(params) {
            try { crypto.randomBytes(0); return { ok: true }; }
            catch (e) { return { error: e.message }; }
          }
        JS
        tool = create_tool(script: script)
        result = tool.runner({}, llm: nil, bot_user: nil).invoke
        expect(result["error"]).to include("between 1 and 1024")
      end
    end

    describe "execution budget" do
      # Regression: crypto callbacks must NOT pause the timer the way HTTP/LLM do.
      # Crypto is CPU work and should count against the script's timeout, otherwise
      # a tool can busy-loop in Ruby/OpenSSL indefinitely.
      #
      # Test shape: a `while (Date.now() < safety)` loop is the worst-case cap on test
      # duration — if the timer is broken and never fires, the loop falls through and
      # returns `ran_to_completion`, which fails the assertion below. A working timer
      # terminates well before that. We deliberately do not assert on wall-clock elapsed:
      # slow CI can add hundreds of ms of scheduling jitter between "budget exceeded" and
      # "Ruby test resumes", and the timeout error is what we actually care about.
      it "counts crypto work against the timeout budget" do
        script = <<~JS
          function invoke(params) {
            const safety = Date.now() + 1500;
            while (Date.now() < safety) {
              crypto.sha256("x");
            }
            return { ran_to_completion: true };
          }
        JS

        tool = create_tool(script: script)
        runner = tool.runner({}, llm: nil, bot_user: nil)
        runner.timeout = 50

        result = runner.invoke

        expect(result[:error]).to eq("Script terminated due to timeout")
      end
    end

    describe "edge cases" do
      it "handles empty string inputs" do
        script = <<~JS
          function invoke(params) {
            return {
              hmac: crypto.hmacSha256("key", ""),
              hash: crypto.sha256(""),
              encode: crypto.base64Encode(""),
            };
          }
        JS

        tool = create_tool(script: script)
        result = tool.runner({}, llm: nil, bot_user: nil).invoke

        expect(result["hmac"]).to eq(OpenSSL::HMAC.hexdigest("SHA256", "key", ""))
        expect(result["hash"]).to eq(Digest::SHA256.hexdigest(""))
        expect(result["encode"]).to eq(Base64.strict_encode64(""))
      end

      it "works for webhook signature verification" do
        secret = "whsec_test123"
        payload = '{"event":"test","data":{"id":1}}'
        expected_sig = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)

        script = <<~JS
          function invoke(params) {
            const signature = crypto.hmacSha256(params.secret, params.payload);
            return { valid: signature === params.expected, signature: signature };
          }
        JS

        tool = create_tool(script: script)
        runner =
          tool.runner(
            { "secret" => secret, "payload" => payload, "expected" => expected_sig },
            llm: nil,
            bot_user: nil,
          )
        result = runner.invoke

        expect(result["valid"]).to eq(true)
        expect(result["signature"]).to eq(expected_sig)
      end
    end
  end
end
