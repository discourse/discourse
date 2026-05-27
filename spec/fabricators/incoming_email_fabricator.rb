# frozen_string_literal: true

Fabricator(:incoming_email) do
  message_id { sequence(:message_id) { |n| "#{n}@example.com" } }
  subject { sequence(:subject) { |n| "Hello world #{n}" } }
  from_address { sequence(:from_address) { |n| "foo#{n}@example.com" } }
  to_addresses { sequence(:to_addresses) { |n| "someone#{n}@else.com" } }
  created_via 0

  raw <<~EMAIL
    Return-Path: <foo@example.com>
    From: Foo <foo@example.com>
    To: someone@else.com
    Subject: Hello world
    Date: Fri, 15 Jan 2016 00:12:43 +0100
    Message-ID: <12345@example.com>
    Mime-Version: 1.0
    Content-Type: text/plain; charset=UTF-8
    Content-Transfer-Encoding: quoted-printable

    The body contains "Hello world" too.
  EMAIL
end

Fabricator(:rejected_incoming_email, from: :incoming_email) do
  is_bounce false
  error "Email::Receiver::BadDestinationAddress"
end
