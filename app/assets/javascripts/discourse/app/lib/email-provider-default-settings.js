const GMAIL = {
  imap: {
    imap_server: "imap.gmail.com",
    imap_port: "993",
    imap_ssl: true,
  },
  smtp: {
    smtp_server: "smtp.gmail.com",
    smtp_port: "587",
    smtp_ssl: true,
  },
};

export default function emailProviderDefaultSettings(provider, protocol) {
  provider = provider.toLowerCase();
  protocol = protocol.toLowerCase();

  switch (provider) {
    case "gmail":
      return GMAIL[protocol];
  }
}
