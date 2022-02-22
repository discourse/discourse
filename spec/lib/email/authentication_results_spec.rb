# frozen_string_literal: true

require "rails_helper"
require "email/authentication_results"

describe Email::AuthenticationResults do
  describe "#results" do
    it "parses 'Nearly Trivial Case: Service Provided, but No Authentication Done' correctly" do
      # https://tools.ietf.org/html/rfc8601#appendix-B.2
      results = described_class.new(" example.org 1; none").results
      expect(results[0][:authserv_id]).to eq "example.org"
      expect(results[0][:resinfo]).to be nil
    end

    it "parses 'Service Provided, Authentication Done' correctly" do
      # https://tools.ietf.org/html/rfc8601#appendix-B.3
      results = described_class.new(<<~EOF
        example.com;
                 spf=pass smtp.mailfrom=example.net
      EOF
      ).results
      expect(results[0][:authserv_id]).to eq "example.com"
      expect(results[0][:resinfo][0][:method]).to eq "spf"
      expect(results[0][:resinfo][0][:result]).to eq "pass"
      expect(results[0][:resinfo][0][:reason]).to be nil
      expect(results[0][:resinfo][0][:props][0][:ptype]).to eq "smtp"
      expect(results[0][:resinfo][0][:props][0][:property]).to eq "mailfrom"
      expect(results[0][:resinfo][0][:props][0][:pvalue]).to eq "example.net"
    end

    it "parses 'Service Provided, Several Authentications Done, Single MTA' correctly" do
      # https://tools.ietf.org/html/rfc8601#appendix-B.4
      results = described_class.new([<<~EOF ,
        example.com;
                  auth=pass (cram-md5) smtp.auth=sender@example.net;
                  spf=pass smtp.mailfrom=example.net
      EOF
      <<~EOF ,
        example.com; iprev=pass
                  policy.iprev=192.0.2.200
      EOF
      ]).results
      expect(results[0][:authserv_id]).to eq "example.com"
      expect(results[0][:resinfo][0][:method]).to eq "auth"
      expect(results[0][:resinfo][0][:result]).to eq "pass"
      expect(results[0][:resinfo][0][:reason]).to be nil
      expect(results[0][:resinfo][0][:props][0][:ptype]).to eq "smtp"
      expect(results[0][:resinfo][0][:props][0][:property]).to eq "auth"
      expect(results[0][:resinfo][0][:props][0][:pvalue]).to eq "sender@example.net"
      expect(results[0][:resinfo][1][:method]).to eq "spf"
      expect(results[0][:resinfo][1][:result]).to eq "pass"
      expect(results[0][:resinfo][1][:reason]).to be nil
      expect(results[0][:resinfo][1][:props][0][:ptype]).to eq "smtp"
      expect(results[0][:resinfo][1][:props][0][:property]).to eq "mailfrom"
      expect(results[0][:resinfo][1][:props][0][:pvalue]).to eq "example.net"
      expect(results[1][:authserv_id]).to eq "example.com"
      expect(results[1][:resinfo][0][:method]).to eq "iprev"
      expect(results[1][:resinfo][0][:result]).to eq "pass"
      expect(results[1][:resinfo][0][:reason]).to be nil
      expect(results[1][:resinfo][0][:props][0][:ptype]).to eq "policy"
      expect(results[1][:resinfo][0][:props][0][:property]).to eq "iprev"
      expect(results[1][:resinfo][0][:props][0][:pvalue]).to eq "192.0.2.200"
    end

    it "parses 'Service Provided, Several Authentications Done, Different MTAs' correctly" do
      # https://tools.ietf.org/html/rfc8601#appendix-B.5
      results = described_class.new([<<~EOF ,
        example.com;
                 dkim=pass (good signature) header.d=example.com
      EOF
      <<~EOF ,
        example.com;
                  auth=pass (cram-md5) smtp.auth=sender@example.com;
                  spf=fail smtp.mailfrom=example.com
      EOF
      ]).results

      expect(results[0][:authserv_id]).to eq "example.com"
      expect(results[0][:resinfo][0][:method]).to eq "dkim"
      expect(results[0][:resinfo][0][:result]).to eq "pass"
      expect(results[0][:resinfo][0][:reason]).to be nil
      expect(results[0][:resinfo][0][:props][0][:ptype]).to eq "header"
      expect(results[0][:resinfo][0][:props][0][:property]).to eq "d"
      expect(results[0][:resinfo][0][:props][0][:pvalue]).to eq "example.com"
      expect(results[1][:authserv_id]).to eq "example.com"
      expect(results[1][:resinfo][0][:method]).to eq "auth"
      expect(results[1][:resinfo][0][:result]).to eq "pass"
      expect(results[1][:resinfo][0][:reason]).to be nil
      expect(results[1][:resinfo][0][:props][0][:ptype]).to eq "smtp"
      expect(results[1][:resinfo][0][:props][0][:property]).to eq "auth"
      expect(results[1][:resinfo][0][:props][0][:pvalue]).to eq "sender@example.com"
      expect(results[1][:resinfo][1][:method]).to eq "spf"
      expect(results[1][:resinfo][1][:result]).to eq "fail"
      expect(results[1][:resinfo][1][:reason]).to be nil
      expect(results[1][:resinfo][1][:props][0][:ptype]).to eq "smtp"
      expect(results[1][:resinfo][1][:props][0][:property]).to eq "mailfrom"
      expect(results[1][:resinfo][1][:props][0][:pvalue]).to eq "example.com"
    end

    it "parses 'Service Provided, Multi-tiered Authentication Done' correctly" do
      # https://tools.ietf.org/html/rfc8601#appendix-B.6
      results = described_class.new([<<~EOF ,
         example.com;
              dkim=pass reason="good signature"
                header.i=@mail-router.example.net;
              dkim=fail reason="bad signature"
                header.i=@newyork.example.com
      EOF
      <<~EOF ,
        example.net;
             dkim=pass (good signature) header.i=@newyork.example.com
      EOF
      ]).results

      expect(results[0][:authserv_id]).to eq "example.com"
      expect(results[0][:resinfo][0][:method]).to eq "dkim"
      expect(results[0][:resinfo][0][:result]).to eq "pass"
      expect(results[0][:resinfo][0][:reason]).to eq "good signature"
      expect(results[0][:resinfo][0][:props][0][:ptype]).to eq "header"
      expect(results[0][:resinfo][0][:props][0][:property]).to eq "i"
      expect(results[0][:resinfo][0][:props][0][:pvalue]).to eq "@mail-router.example.net"
      expect(results[0][:resinfo][1][:method]).to eq "dkim"
      expect(results[0][:resinfo][1][:result]).to eq "fail"
      expect(results[0][:resinfo][1][:reason]).to eq "bad signature"
      expect(results[0][:resinfo][1][:props][0][:ptype]).to eq "header"
      expect(results[0][:resinfo][1][:props][0][:property]).to eq "i"
      expect(results[0][:resinfo][1][:props][0][:pvalue]).to eq "@newyork.example.com"
      expect(results[1][:authserv_id]).to eq "example.net"
      expect(results[1][:resinfo][0][:method]).to eq "dkim"
      expect(results[1][:resinfo][0][:result]).to eq "pass"
      expect(results[1][:resinfo][0][:reason]).to be nil
      expect(results[1][:resinfo][0][:props][0][:ptype]).to eq "header"
      expect(results[1][:resinfo][0][:props][0][:property]).to eq "i"
      expect(results[1][:resinfo][0][:props][0][:pvalue]).to eq "@newyork.example.com"
    end

    it "parses 'Comment-Heavy Example' correctly" do
      # https://tools.ietf.org/html/rfc8601#appendix-B.7
      results = described_class.new(<<~EOF
        foo.example.net (foobar) 1 (baz);
          dkim (Because I like it) / 1 (One yay) = (wait for it) fail
            policy (A dot can go here) . (like that) expired
            (this surprised me) = (as I wasn't expecting it) 1362471462
      EOF
      ).results

      expect(results[0][:authserv_id]).to eq "foo.example.net"
      expect(results[0][:resinfo][0][:method]).to eq "dkim"
      expect(results[0][:resinfo][0][:result]).to eq "fail"
      expect(results[0][:resinfo][0][:reason]).to be nil
      expect(results[0][:resinfo][0][:props][0][:ptype]).to eq "policy"
      expect(results[0][:resinfo][0][:props][0][:property]).to eq "expired"
      expect(results[0][:resinfo][0][:props][0][:pvalue]).to eq "1362471462"
    end

    it "parses header with no props correctly" do
      results = described_class.new(" example.com; dmarc=pass").results
      expect(results[0][:authserv_id]).to eq "example.com"
      expect(results[0][:resinfo][0][:method]).to eq "dmarc"
      expect(results[0][:resinfo][0][:result]).to eq "pass"
      expect(results[0][:resinfo][0][:reason]).to be nil
      expect(results[0][:resinfo][0][:props]).to eq []
    end

    it "parses header with multiple props correctly" do
      results = described_class.new(<<~EOF
        mx.google.com;
      dkim=pass header.i=@email.example.com header.s=20111006 header.b=URn9MW+F;
      spf=pass (google.com: domain of foo@b.email.example.com designates 1.2.3.4 as permitted sender) smtp.mailfrom=foo@b.email.example.com;
      dmarc=pass (p=REJECT sp=REJECT dis=NONE) header.from=email.example.com
      EOF
      ).results

      expect(results[0][:authserv_id]).to eq "mx.google.com"
      expect(results[0][:resinfo][0][:method]).to eq "dkim"
      expect(results[0][:resinfo][0][:result]).to eq "pass"
      expect(results[0][:resinfo][0][:reason]).to be nil
      expect(results[0][:resinfo][0][:props][0][:ptype]).to eq "header"
      expect(results[0][:resinfo][0][:props][0][:property]).to eq "i"
      expect(results[0][:resinfo][0][:props][0][:pvalue]).to eq "@email.example.com"
      expect(results[0][:resinfo][0][:props][1][:ptype]).to eq "header"
      expect(results[0][:resinfo][0][:props][1][:property]).to eq "s"
      expect(results[0][:resinfo][0][:props][1][:pvalue]).to eq "20111006"
      expect(results[0][:resinfo][0][:props][2][:ptype]).to eq "header"
      expect(results[0][:resinfo][0][:props][2][:property]).to eq "b"
      expect(results[0][:resinfo][0][:props][2][:pvalue]).to eq "URn9MW+F"
      expect(results[0][:resinfo][1][:method]).to eq "spf"
      expect(results[0][:resinfo][1][:result]).to eq "pass"
      expect(results[0][:resinfo][1][:reason]).to be nil
      expect(results[0][:resinfo][1][:props][0][:ptype]).to eq "smtp"
      expect(results[0][:resinfo][1][:props][0][:property]).to eq "mailfrom"
      expect(results[0][:resinfo][1][:props][0][:pvalue]).to eq "foo@b.email.example.com"
      expect(results[0][:resinfo][2][:method]).to eq "dmarc"
      expect(results[0][:resinfo][2][:result]).to eq "pass"
      expect(results[0][:resinfo][2][:reason]).to be nil
      expect(results[0][:resinfo][2][:props][0][:ptype]).to eq "header"
      expect(results[0][:resinfo][2][:props][0][:property]).to eq "from"
      expect(results[0][:resinfo][2][:props][0][:pvalue]).to eq "email.example.com"
    end
  end

  describe "#verdict" do
    before do
      SiteSetting.email_in_authserv_id = "valid.com"
    end

    shared_examples "is verdict" do |verdict|
      it "is #{verdict}" do
        expect(described_class.new(headers).verdict).to eq verdict
      end
    end

    context "with no authentication-results headers" do
      let(:headers) { "" }

      it "is gray" do
        expect(described_class.new(headers).verdict).to eq :gray
      end
    end

    context "with a single authentication-results header" do
      context "with a valid fail" do
        let(:headers) { "valid.com; dmarc=fail" }
        include_examples "is verdict", :fail
      end

      context "with a valid pass" do
        let(:headers) { "valid.com; dmarc=pass" }
        include_examples "is verdict", :pass
      end

      context "with a valid error" do
        let(:headers) { "valid.com; dmarc=error" }
        include_examples "is verdict", :gray
      end

      context "with no email_in_authserv_id set" do
        before { SiteSetting.email_in_authserv_id = "" }

        context "with a fail" do
          let(:headers) { "foobar.com; dmarc=fail" }
          include_examples "is verdict", :gray
        end

        context "with a pass" do
          let(:headers) { "foobar.com; dmarc=pass" }
          include_examples "is verdict", :gray
        end
      end
    end

    context "with multiple authentication-results headers" do
      context "with a valid fail, and an invalid pass" do
        let(:headers) { ["valid.com; dmarc=fail", "invalid.com; dmarc=pass"] }
        include_examples "is verdict", :fail
      end

      context "with a valid fail, and a valid pass" do
        let(:headers) { ["valid.com; dmarc=fail", "valid.com; dmarc=pass"] }
        include_examples "is verdict", :fail
      end

      context "with a valid error, and a valid pass" do
        let(:headers) { ["valid.com; dmarc=foobar", "valid.com; dmarc=pass"] }
        include_examples "is verdict", :pass
      end

      context "with no email_in_authserv_id set" do
        before { SiteSetting.email_in_authserv_id = "" }

        context "with an error, and a pass" do
          let(:headers) { ["foobar.com; dmarc=foobar", "foobar.com; dmarc=pass"] }
          include_examples "is verdict", :gray
        end
      end
    end
  end

  describe "#action" do
    it "enqueues a fail verdict" do
      results = described_class.new("")
      results.expects(:verdict).returns(:fail)
      expect(results.action).to eq (:enqueue)
    end

    it "accepts a pass verdict" do
      results = described_class.new("")
      results.expects(:verdict).returns(:pass)
      expect(results.action).to eq (:accept)
    end

    it "accepts a gray verdict" do
      results = described_class.new("")
      results.expects(:verdict).returns(:gray)
      expect(results.action).to eq (:accept)
    end
  end

end
