import { GROUP_SMTP_SSL_MODES } from "discourse/lib/constants";

const GMAIL = {
  imap: {
    imap_server: "imap.gmail.com",
    imap_port: "993",
    imap_ssl: true,
  },
  smtp: {
    smtp_server: "smtp.gmail.com",
    smtp_port: "587",
    smtp_ssl_mode: GROUP_SMTP_SSL_MODES.starttls,
  },
};

const OUTLOOK = {
  smtp: {
    smtp_server: "smtp-mail.outlook.com",
    smtp_port: "587",
    smtp_ssl_mode: GROUP_SMTP_SSL_MODES.starttls,
  },
};

const OFFICE365 = {
  smtp: {
    smtp_server: "smtp.office365.com",
    smtp_port: "587",
    smtp_ssl_mode: GROUP_SMTP_SSL_MODES.starttls,
  },
};

export default function emailProviderDefaultSettings(provider, protocol) {
  provider = provider.toLowerCase();
  protocol = protocol.toLowerCase();

  switch (provider) {
    case "gmail":
      return GMAIL[protocol];
    case "office365":
      return OFFICE365[protocol];
    case "outlook":
      return OUTLOOK[protocol];
  }
}
