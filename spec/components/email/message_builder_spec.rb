require 'rails_helper'
require 'email/message_builder'

describe Email::MessageBuilder do

  let(:to_address) { "jake@adventuretime.ooo" }
  let(:subject) { "Tree Trunks has made some apple pie!" }
  let(:body) { "oh my glob Jake, Tree Trunks just made the tastiest apple pie ever!" }
  let(:builder) { Email::MessageBuilder.new(to_address, subject: subject, body: body) }
  let(:build_args) { builder.build_args }
  let(:header_args) { builder.header_args }
  let(:allow_reply_header) { described_class::ALLOW_REPLY_BY_EMAIL_HEADER }

  it "has the correct to address" do
    expect(build_args[:to]).to eq(to_address)
  end

  it "has the subject" do
    expect(builder.subject).to eq(subject)
  end

  it "has the body" do
    expect(builder.body).to eq(body)
  end

  it "has a utf-8 charset" do
    expect(builder.build_args[:charset]).to eq("UTF-8")
  end

  it "ask politely not to receive automated responses" do
    expect(header_args['X-Auto-Response-Suppress']).to eq("All")
  end

  context "reply by email" do

    context "without allow_reply_by_email" do
      it "does not have a X-Discourse-Reply-Key" do
        expect(header_args['X-Discourse-Reply-Key']).to be_blank
      end

      it "returns a Reply-To header that's the same as From" do
        expect(header_args['Reply-To']).to eq(build_args[:from])
      end
    end

    context "with allow_reply_by_email" do
      let(:reply_by_email_builder) { Email::MessageBuilder.new(to_address, allow_reply_by_email: true) }

      context "With the SiteSetting enabled" do
        before do
          SiteSetting.stubs(:reply_by_email_enabled?).returns(true)
          SiteSetting.stubs(:reply_by_email_address).returns("r+%{reply_key}@reply.myforum.com")
        end

        it "returns a Reply-To header with the reply key" do
          expect(reply_by_email_builder.header_args['Reply-To'])
            .to eq("\"#{SiteSetting.title}\" <r+%{reply_key}@reply.myforum.com>")

          expect(reply_by_email_builder.header_args[allow_reply_header])
            .to eq(true)
        end

        it "cleans up the site title" do
          SiteSetting.stubs(:title).returns(">>>Obnoxious Title: Deal, \"With\" It<<<")

          expect(reply_by_email_builder.header_args['Reply-To'])
            .to eq("\"Obnoxious Title Deal With It\" <r+%{reply_key}@reply.myforum.com>")

          expect(reply_by_email_builder.header_args[allow_reply_header])
            .to eq(true)
        end
      end

      context "With the SiteSetting disabled" do
        before do
          SiteSetting.stubs(:reply_by_email_enabled?).returns(false)
        end

        it "returns a Reply-To header that's the same as From" do
          expect(reply_by_email_builder.header_args['Reply-To'])
            .to eq(reply_by_email_builder.build_args[:from])

          expect(reply_by_email_builder.header_args[allow_reply_header])
            .to eq(nil)
        end
      end
    end

    context "with allow_reply_by_email" do
      let(:reply_by_email_builder) do
        Email::MessageBuilder.new(to_address,
          allow_reply_by_email: true,
          private_reply: true,
          from_alias: "Username"
        )
      end

      context "With the SiteSetting enabled" do
        before do
          SiteSetting.stubs(:reply_by_email_enabled?).returns(true)

          SiteSetting.stubs(:reply_by_email_address)
            .returns("r+%{reply_key}@reply.myforum.com")
        end

        it "returns a Reply-To header with the reply key" do
          expect(reply_by_email_builder.header_args['Reply-To'])
            .to eq("\"Username\" <r+%{reply_key}@reply.myforum.com>")

          expect(reply_by_email_builder.header_args[allow_reply_header])
            .to eq(true)
        end
      end

      context "With the SiteSetting disabled" do
        before do
          SiteSetting.stubs(:reply_by_email_enabled?).returns(false)
        end

        it "returns a Reply-To header that's the same as From" do
          expect(reply_by_email_builder.header_args['Reply-To'])
            .to eq(reply_by_email_builder.build_args[:from])

          expect(reply_by_email_builder.header_args[allow_reply_header])
            .to eq(nil)
        end
      end
    end

  end

  context "custom headers" do

    let(:custom_headers_string) { " Precedence : bulk | :: | No-colon | No-Value: | Multi-colon : : value : : | Auto-Submitted : auto-generated " }
    let(:custom_headers_result) { { "Precedence" => "bulk", "Multi-colon" => ": value : :", "Auto-Submitted" => "auto-generated" } }

    it "custom headers builder" do
      expect(Email::MessageBuilder.custom_headers(custom_headers_string)).to eq(custom_headers_result)
    end

    it "empty headers builder" do
      expect(Email::MessageBuilder.custom_headers("")).to eq({})
    end

    it "null headers builder" do
      expect(Email::MessageBuilder.custom_headers(nil)).to eq({})
    end

  end

  context "header args" do

    let(:message_with_header_args) do
      Email::MessageBuilder.new(
        to_address,
        body: 'hello world',
        topic_id: 1234,
        post_id: 4567,
      )
    end

    it "passes through a post_id" do
      expect(message_with_header_args.header_args['X-Discourse-Post-Id']).to eq('4567')
    end

    it "passes through a topic_id" do
      expect(message_with_header_args.header_args['X-Discourse-Topic-Id']).to eq('1234')
    end

  end

  context "unsubscribe link" do

    context "with add_unsubscribe_link false" do
      it "has no unsubscribe header by default" do
        expect(builder.header_args['List-Unsubscribe']).to be_blank
      end

      it "doesn't have the user preferences url in the body" do
        expect(builder.body).not_to match(builder.template_args[:user_preferences_url])
      end

    end

    context "with add_unsubscribe_link true" do

      let(:message_with_unsubscribe) { Email::MessageBuilder.new(to_address,
                                                                body: 'hello world',
                                                                add_unsubscribe_link: true,
                                                                url: "/t/1234",
                                                                unsubscribe_url: "/t/1234/unsubscribe") }

      it "has an List-Unsubscribe header" do
        expect(message_with_unsubscribe.header_args['List-Unsubscribe']).to be_present
      end

      it "has the unsubscribe url in the body" do
        expect(message_with_unsubscribe.body).to match('/t/1234/unsubscribe')
      end

      it "does not add unsubscribe via email link without site setting set" do
        expect(message_with_unsubscribe.body).to_not match(/mailto:reply@#{Discourse.current_hostname}\?subject=unsubscribe/)
      end

    end

  end

  context "template_args" do
    let(:template_args) { builder.template_args }

    it "has site title as email_prefix when `SiteSetting.email_prefix` is not present" do
      expect(template_args[:email_prefix]).to eq(SiteSetting.title)
    end

    it "has email prefix as email_prefix when `SiteSetting.email_prefix` is present" do
      SiteSetting.email_prefix = 'some email prefix'
      expect(template_args[:email_prefix]).to eq(SiteSetting.email_prefix)
    end

    it "has the base url" do
      expect(template_args[:base_url]).to eq(Discourse.base_url)
    end

    it "has the user_preferences_url" do
      expect(template_args[:user_preferences_url]).to eq("#{Discourse.base_url}/my/preferences")
    end
  end

  context "email prefix in subject" do
    context "when use_site_subject is true" do
      let(:message_with_email_prefix) { Email::MessageBuilder.new(to_address,
                                                                  body: 'hello world',
                                                                  use_site_subject: true) }

      it "when email_prefix is set it should be present in subject" do
        SiteSetting.email_prefix = 'some email prefix'
        expect(message_with_email_prefix.subject).to match(SiteSetting.email_prefix)
      end
    end
  end

  context "subject_template" do

    let(:templated_builder) { Email::MessageBuilder.new(to_address, template: 'mystery') }
    let(:rendered_template) { "rendered template" }

    it "has the body rendered from a template" do
      I18n.expects(:t).with("mystery.text_body_template", templated_builder.template_args).returns(rendered_template)
      expect(templated_builder.body).to eq(rendered_template)
    end

    it "has the subject rendered from a template" do
      I18n.expects(:t).with("mystery.subject_template", templated_builder.template_args).returns(rendered_template)
      expect(templated_builder.subject).to eq(rendered_template)
    end

  end

  context "from field" do

    it "has the default from" do
      SiteSetting.title = ""
      expect(build_args[:from]).to eq(SiteSetting.notification_email)
    end

    it "title setting will be added if present" do
      SiteSetting.title = "Dog Talk"
      expect(build_args[:from]).to eq("\"Dog Talk\" <#{SiteSetting.notification_email}>")
    end

    let(:finn_email) { 'finn@adventuretime.ooo' }
    let(:custom_from) { Email::MessageBuilder.new(to_address, from: finn_email).build_args }

    it "allows us to override from" do
      expect(custom_from[:from]).to eq(finn_email)
    end

    let(:aliased_from) { Email::MessageBuilder.new(to_address, from_alias: "Finn the Dog") }

    it "allows us to alias the from address" do
      expect(aliased_from.build_args[:from]).to eq("\"Finn the Dog\" <#{SiteSetting.notification_email}>")
    end

    let(:custom_aliased_from) { Email::MessageBuilder.new(to_address,
                                                          from_alias: "Finn the Dog",
                                                          from: finn_email) }

    it "allows us to alias a custom from address" do
      expect(custom_aliased_from.build_args[:from]).to eq("\"Finn the Dog\" <#{finn_email}>")
    end

    it "email_site_title will be added if it's set" do
      SiteSetting.email_site_title = "The Forum"
      expect(build_args[:from]).to eq("\"The Forum\" <#{SiteSetting.notification_email}>")
    end

    it "email_site_title overrides title" do
      SiteSetting.title = "Dog Talk"
      SiteSetting.email_site_title = "The Forum"
      expect(build_args[:from]).to eq("\"The Forum\" <#{SiteSetting.notification_email}>")
    end

    it "cleans up aliases in the from_alias arg" do
      builder = Email::MessageBuilder.new(to_address, from_alias: "Finn: the Dog, <3", from: finn_email)
      expect(builder.build_args[:from]).to eq("\"Finn the Dog 3\" <#{finn_email}>")
    end

    it "cleans up the email_site_title" do
      SiteSetting.stubs(:email_site_title).returns("::>>>Best \"Forum\", EU: Award Winning<<<")
      expect(build_args[:from]).to eq("\"Best Forum EU Award Winning\" <#{SiteSetting.notification_email}>")
    end

  end

end
