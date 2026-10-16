# frozen_string_literal: true

require "email/authentication_results"

RSpec.describe Email::AuthenticationResults do
  def resinfo(method, result, *props, reason: nil)
    {
      method:,
      result:,
      reason:,
      props:
        props.map do |p|
          p.split(/[.=]/, 3).then { |t, k, v| { ptype: t, property: k, pvalue: v } }
        end,
    }
  end

  describe "#results" do
    it "parses 'Nearly Trivial Case: Service Provided, but No Authentication Done' correctly" do
      # https://tools.ietf.org/html/rfc8601#appendix-B.2
      expect(described_class.new(" example.org 1; none").results).to eq(
        [{ authserv_id: "example.org", resinfo: [] }],
      )
    end

    it "parses 'Service Provided, Authentication Done' correctly" do
      # https://tools.ietf.org/html/rfc8601#appendix-B.3
      results = described_class.new(<<~RAW).results
        example.com;
                 spf=pass smtp.mailfrom=example.net
      RAW

      expect(results).to eq(
        [
          {
            authserv_id: "example.com",
            resinfo: [resinfo("spf", "pass", "smtp.mailfrom=example.net")],
          },
        ],
      )
    end

    it "parses 'Service Provided, Several Authentications Done, Single MTA' correctly" do
      # https://tools.ietf.org/html/rfc8601#appendix-B.4
      results = described_class.new([<<~RAW, <<~RAW]).results
        example.com;
                  auth=pass (cram-md5) smtp.auth=sender@example.net;
                  spf=pass smtp.mailfrom=example.net
      RAW
        example.com; iprev=pass
                  policy.iprev=192.0.2.200
      RAW

      expect(results).to eq(
        [
          {
            authserv_id: "example.com",
            resinfo: [
              resinfo("auth", "pass", "smtp.auth=sender@example.net"),
              resinfo("spf", "pass", "smtp.mailfrom=example.net"),
            ],
          },
          {
            authserv_id: "example.com",
            resinfo: [resinfo("iprev", "pass", "policy.iprev=192.0.2.200")],
          },
        ],
      )
    end

    it "parses 'Service Provided, Several Authentications Done, Different MTAs' correctly" do
      # https://tools.ietf.org/html/rfc8601#appendix-B.5
      results = described_class.new([<<~RAW, <<~RAW]).results
        example.com;
                 dkim=pass (good signature) header.d=example.com
      RAW
        example.com;
                  auth=pass (cram-md5) smtp.auth=sender@example.com;
                  spf=fail smtp.mailfrom=example.com
      RAW

      expect(results).to eq(
        [
          {
            authserv_id: "example.com",
            resinfo: [resinfo("dkim", "pass", "header.d=example.com")],
          },
          {
            authserv_id: "example.com",
            resinfo: [
              resinfo("auth", "pass", "smtp.auth=sender@example.com"),
              resinfo("spf", "fail", "smtp.mailfrom=example.com"),
            ],
          },
        ],
      )
    end

    it "parses 'Service Provided, Multi-tiered Authentication Done' correctly" do
      # https://tools.ietf.org/html/rfc8601#appendix-B.6
      results = described_class.new([<<~RAW, <<~RAW]).results
         example.com;
              dkim=pass reason="good signature"
                header.i=@mail-router.example.net;
              dkim=fail reason="bad signature"
                header.i=@newyork.example.com
      RAW
        example.net;
             dkim=pass (good signature) header.i=@newyork.example.com
      RAW

      expect(results).to eq(
        [
          {
            authserv_id: "example.com",
            resinfo: [
              resinfo(
                "dkim",
                "pass",
                "header.i=@mail-router.example.net",
                reason: "good signature",
              ),
              resinfo("dkim", "fail", "header.i=@newyork.example.com", reason: "bad signature"),
            ],
          },
          {
            authserv_id: "example.net",
            resinfo: [resinfo("dkim", "pass", "header.i=@newyork.example.com")],
          },
        ],
      )
    end

    it "parses 'Comment-Heavy Example' correctly" do
      # https://tools.ietf.org/html/rfc8601#appendix-B.7
      results = described_class.new(<<~RAW).results
        foo.example.net (foobar) 1 (baz);
          dkim (Because I like it) / 1 (One yay) = (wait for it) fail
            policy (A dot can go here) . (like that) expired
            (this surprised me) = (as I wasn't expecting it) 1362471462
      RAW

      expect(results).to eq(
        [
          {
            authserv_id: "foo.example.net",
            resinfo: [resinfo("dkim", "fail", "policy.expired=1362471462")],
          },
        ],
      )
    end

    it "parses header with multiple props and quoted values correctly" do
      results = described_class.new(<<~RAW).results
        "mx.google.com";
      dkim=pass header.i=@email.example.com header.s=20111006 header.b="URn9MW+F" (comment);
      spf=pass (google.com: domain of foo@b.email.example.com designates 1.2.3.4 as permitted sender) smtp.mailfrom=foo@b.email.example.com;
      dmarc=pass (p=REJECT sp=REJECT dis=NONE) header.from=email.example.com
      RAW

      expect(results).to eq(
        [
          {
            authserv_id: "mx.google.com",
            resinfo: [
              resinfo(
                "dkim",
                "pass",
                "header.i=@email.example.com",
                "header.s=20111006",
                "header.b=URn9MW+F",
              ),
              resinfo("spf", "pass", "smtp.mailfrom=foo@b.email.example.com"),
              resinfo("dmarc", "pass", "header.from=email.example.com"),
            ],
          },
        ],
      )
    end

    it "doesn't mistake a method starting with 'none' for a no-result" do
      expect(described_class.new("example.com; nonexistent=pass").results).to eq(
        [{ authserv_id: "example.com", resinfo: [resinfo("nonexistent", "pass")] }],
      )
    end

    it "only keeps results from the configured authserv-id" do
      SiteSetting.email_in_authserv_id = "valid.com"

      expect(
        described_class.new(["valid.com; dmarc=pass", "invalid.com; dmarc=fail"]).results,
      ).to eq([{ authserv_id: "valid.com", resinfo: [resinfo("dmarc", "pass")] }])
    end
  end

  describe "#verdict and #action" do
    before { SiteSetting.email_in_authserv_id = "valid.com" }

    {
      "" => %i[gray accept],
      "valid.com; dmarc=pass" => %i[pass accept],
      "valid.com; dmarc=fail" => %i[fail enqueue],
      "valid.com; DMARC=Fail" => %i[fail enqueue],
      "valid.com; dmarc=error" => %i[gray accept],
      "valid.com; none" => %i[gray accept],
      "valid.com 1; NONE (no checks run)" => %i[gray accept],
      "valid.com; none (a=b; dmarc=fail)" => %i[gray accept],
      "valid.com; none; dmarc=fail" => %i[fail enqueue],
      ["valid.com; dmarc=pass", "invalid.com; dmarc=fail"] => %i[pass accept],
      ["valid.com; dmarc=fail", "valid.com; dmarc=pass"] => %i[fail enqueue],
      ["valid.com; dmarc=fail", "valid.com; none"] => %i[fail enqueue],
      ["valid.com; dmarc=foobar", "valid.com; dmarc=pass"] => %i[pass accept],
    }.each do |headers, (verdict, action)|
      it "is #{verdict} and #{action}s #{headers.inspect}" do
        results = described_class.new(headers)
        expect(results.verdict).to eq(verdict)
        expect(results.action).to eq(action)
      end
    end

    it "is gray without a configured authserv-id" do
      SiteSetting.email_in_authserv_id = ""

      results = described_class.new("foobar.com; dmarc=fail")
      expect(results.verdict).to eq(:gray)
      expect(results.action).to eq(:accept)
    end
  end
end
